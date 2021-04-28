import FungibleToken from 0x01
import FlowToken from 0x02
import EducationFund from 0x03

// parent deposit

// assume parent account initialized
transaction(depositAmount: UFix64) {
    var receiverRef: &FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}
    var temporaryVault: @FungibleToken.Vault

    prepare(parent: AuthAccount) {
        // Typical functionality //
        let recipient = getAccount(0x03)

        // Get the public receiver capability
        let cap = recipient.getCapability(/public/MainReceiver)

        // Borrow a reference from the capability
        self.receiverRef = cap.borrow<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>()
            ?? panic("Could not borrow a reference to the education fund receiver")

        let parentVaultRef = parent.borrow<&FungibleToken.Vault>(from: /storage/MainVault, )!

        self.temporaryVault <- parentVaultRef.withdraw(amount: depositAmount)


        // Increasing current tinme (child age artificially for reasons discussed) // 
        let vaultGateway = parent.borrow<&EducationFund.ParentClient>(from: /storage/EducationFundClient)!.retrieveGateway()!.borrow()! 

        vaultGateway.timeTravel(ageUp: 9)
    }

    execute {
        self.receiverRef.deposit(from: <- self.temporaryVault)
        log("parent deposit succeded!")
    }
}