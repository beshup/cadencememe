import FungibleToken from 0x01
import FlowToken from 0x02
import EducationFund from 0x03

// initialize child transaction

// assume edu fund has already been deployed
transaction() {
    prepare(fundAccount: AuthAccount, childAccount: AuthAccount) {
      // add withdraw and recieve capabilities to child acct
      childAccount.save<@FungibleToken.Vault>(<-FlowToken.createEmptyVault(), to: /storage/MainVault)

      let ReceiverRef = childAccount.link<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>(/private/Receiver, target: /storage/MainVault)
      // make sure not nil, or else, it exists at that path

      let WithdrawRef = childAccount.link<&FlowToken.Vault{FungibleToken.Provider, FungibleToken.Balance}>(/private/Withdraw, target: /storage/MainVault)
      // make sure not nil, or else, it exists at that path

      let BalanceRef = childAccount.link<&FlowToken.Vault{FungibleToken.Balance}>(/public/Balance, target: /storage/MainVault)

      let childCap = fundAccount.getCapability<&EducationFund.VaultGateway{EducationFund.Child}>(/private/Child)
      
      let childClient <- EducationFund.createChildClient()        
      childClient.addCapability(childCap)    

      childAccount.save<@EducationFund.ChildClient>(<-childClient, to: /storage/EducationFundClient)                 
    }
}