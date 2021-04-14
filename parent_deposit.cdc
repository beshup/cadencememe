import FungibleToken from 0x01
import EducationFund from 0x03

// parent deposit

// assume parent account initialized
transaction(depositAmount: UFix64, currentTime: UInt64) {
    prepare(parent: AuthAccount) {
        let eduClient = parent.borrow<&EducationFund.ParentClient>(from: /storage/EducationFundClient)!
        let vaultGateway = eduClient.retrieveGateway()!.borrow()! 

        let parentVaultRef = parent.borrow<&FungibleToken.Vault>(from: /storage/MainVault)!

        vaultGateway.deposit(from: <- parentVaultRef.withdraw(amount: depositAmount), currentTime: currentTime)
    }
}