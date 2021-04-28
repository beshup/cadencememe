import FungibleToken from 0x01
import FlowToken from 0x02
import EducationFund from 0x03

// initialize system transaction

transaction() {
    // Temporary Vault object that holds the balance that is being transferred (just to initiliaze parent with money)
    var temporaryVault: @FungibleToken.Vault

    prepare(flowTokenAccount: AuthAccount, fundAccount: AuthAccount, parentAccount: AuthAccount, childAccount: AuthAccount) {
      // PARENT
      // add withdraw and recieve capabilities to parent acct
      parentAccount.save<@FungibleToken.Vault>(<-FlowToken.createEmptyVault(), to: /storage/MainVault)

      let ReceiverRef = parentAccount.link<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>(/public/Receiver, target: /storage/MainVault)
      // make sure not nil, or else, it exists at that path

      let WithdrawRef = parentAccount.link<&FlowToken.Vault{FungibleToken.Provider, FungibleToken.Balance}>(/private/Withdraw, target: /storage/MainVault)
      // make sure not nil, or else, it exists at that path

      let BalanceRef = parentAccount.link<&FlowToken.Vault{FungibleToken.Balance}>(/public/Balance, target: /storage/MainVault)

      let parentCap = fundAccount.getCapability<&EducationFund.VaultGateway{EducationFund.Parent}>(/private/Parent)
      
      let parentClient <- EducationFund.createParentClient()        
      parentClient.addCapability(parentCap)      

      parentAccount.save<@EducationFund.ParentClient>(<-parentClient, to: /storage/EducationFundClient)          

      // CHILD

      // add withdraw and recieve capabilities to child acct
      childAccount.save<@FungibleToken.Vault>(<-FlowToken.createEmptyVault(), to: /storage/MainVault)

      let ReceiverRef2 = childAccount.link<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>(/private/Receiver, target: /storage/MainVault)
      // make sure not nil, or else, it exists at that path

      let WithdrawRef2 = childAccount.link<&FlowToken.Vault{FungibleToken.Provider, FungibleToken.Balance}>(/private/Withdraw, target: /storage/MainVault)
      // make sure not nil, or else, it exists at that path

      let BalanceRef2 = childAccount.link<&FlowToken.Vault{FungibleToken.Balance}>(/public/Balance, target: /storage/MainVault)

      let childCap = fundAccount.getCapability<&EducationFund.VaultGateway{EducationFund.Child}>(/private/Child)
      
      let childClient <- EducationFund.createChildClient()        
      childClient.addCapability(childCap)    

      childAccount.save<@EducationFund.ChildClient>(<-childClient, to: /storage/EducationFundClient)    

      // MONEY IN PARENT's ACCT 
      // take from FlowToken's balance
      let vaultRef = flowTokenAccount.borrow<&FungibleToken.Vault>(from: /storage/flowTokenVault)
          ?? panic("Could not borrow a reference to the owner's vault")

      self.temporaryVault <- vaultRef.withdraw(amount: 100.0)
    }

    execute {
      // get the parent's public account object
      let recipient = getAccount(0x04)

      // get the parent's Receiver reference to their Vault
      // by borrowing the reference from the public capability
      let receiverRef = recipient.getCapability(/public/Receiver)
                        .borrow<&FlowToken.Vault{FungibleToken.Receiver}>()
                        ?? panic("Could not borrow a reference to the receiver")

      // deposit tokens to their Vault
      receiverRef.deposit(from: <-self.temporaryVault)

      log("initialization succeeded!")
    }
}