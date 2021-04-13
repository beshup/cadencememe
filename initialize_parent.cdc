import FungibleToken from 0x01
import FlowToken from 0x02
import EducationFund from 0x03

// initialize parent transaction

transaction() {
    prepare(fundAccount: AuthAccount, parentAccount: AuthAccount) {
      // add withdraw and recieve capabilities to parent acct
      parentAccount.save<@FungibleToken.Vault>(<-FlowToken.createEmptyVault(), to: /storage/MainVault)

      let ReceiverRef = parentAccount.link<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>(/private/Receiver, target: /storage/MainVault)
      // make sure not nil, or else, it exists at that path

      let WithdrawRef = parentAccount.link<&FlowToken.Vault{FungibleToken.Provider, FungibleToken.Balance}>(/private/Withdraw, target: /storage/MainVault)
      // make sure not nil, or else, it exists at that path

      let parentCap = fundAccount.getCapability<&EducationFund.VaultGateway{EducationFund.Parent}>(/private/Parent)
      
      let parentClient <- EducationFund.createParentClient()        
      parentClient.addCapability(parentCap)      

      parentAccount.save<@EducationFund.ParentClient>(<-parentClient, to: /storage/EducationFundClient)
      let ClientRef = parentAccount.link<&EducationFund.ParentClient>(/private/EducationFundClient, target: /storage/EducationFundClient)                                    
    }
}
