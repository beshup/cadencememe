import FungibleToken from 0x01
import EducationFund from 0x03

// child withdraw

// assume child account initialized
transaction(depositAmount: UFix64, currentTime: UInt64) {
    prepare(child: AuthAccount) {
        let eduClient = child.borrow<&EducationFund.ChildClient>(from: /storage/EducationFundClient)!
        let vaultGateway = eduClient.retrieveGateway()!.borrow()! 

        let childVaultRef = child.borrow<&FungibleToken.Vault>(from: /storage/MainVault)!

        childVaultRef.deposit(from: <- vaultGateway.withdraw(amount: depositAmount, currentTime: currentTime))
    }
}