import EducationFund from 0x03

// parent increase limit

// assume parent account initialized
transaction(limitIncrement: UFix64) {
    prepare(parent: AuthAccount) {
        let eduClient = parent.borrow<&EducationFund.ParentClient>(from: /storage/EducationFundClient)!
        let vaultGateway = eduClient.retrieveGateway()!.borrow()! 

        vaultGateway.increaseLimit(limitIncrement: limitIncrement)

        vaultGateway.timeTravel(ageUp: 1)
        log("limit successfully increased")
    }
}