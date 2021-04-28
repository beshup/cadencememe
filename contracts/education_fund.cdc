import FungibleToken from 0x01
import FlowToken from 0x02

access(all) contract EducationFund {
  pub resource interface Child {
    access(contract) let adultTime: UInt64
    access(contract) var limit: UFix64
    access(contract) var amountWithdrawn: UFix64
    access(contract) var currentTime: UInt64 

    pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
      pre {
        self.currentTime >= self.adultTime: "Child has to be adult to withdraw"
        self.amountWithdrawn + amount < self.limit: "Cannot exceed withdraw limit"
      } 
    }
  }

  pub resource interface Parent {
    access(contract) let adultTime: UInt64
    access(contract) var currentTime: UInt64 

    pub fun increaseLimit(limitIncrement: UFix64) {
      pre {
        self.currentTime >= self.adultTime: "Cannot increase limit before child is adult"
      }
    }

    pub fun timeTravel(ageUp: UInt64)
  }

  pub resource interface ReadState {
    pub fun readlimit(): UFix64
    pub fun readAmountWithdrawn(): UFix64
    pub fun readFundBalance(): UFix64
    pub fun readCurrentTime(): UInt64
  }


  access(all) resource VaultGateway: Child, Parent, ReadState {
    // assume times stored as unix timestamp (client handles conversion) 
    access(contract) let adultTime: UInt64
    access(contract) var limit: UFix64
    access(contract) var amountWithdrawn: UFix64

    // unfortunately we have to keep track of this as getting the block timestamp isn't supported in the playground
    access(contract) var currentTime: UInt64 

    access(self) var withdrawer: Capability<&FlowToken.Vault{FungibleToken.Provider, FungibleToken.Balance}>

    pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
      let ref = self.withdrawer.borrow() ?? panic("Could not borrow withdrawer")
      let withdrawVault <- ref.withdraw(amount: amount)
      self.amountWithdrawn = self.amountWithdrawn + amount
      return <- withdrawVault
    } 

    pub fun increaseLimit(limitIncrement: UFix64) {
      let ref = self.withdrawer.borrow() ?? panic("Could not borrow receiver")
      let proposedLimit = self.limit + limitIncrement

      if (proposedLimit <= self.amountWithdrawn + ref.balance) {
        self.limit = self.limit + limitIncrement
      } 
      else {
        panic("Limit exceeds withdraw capability for child, see fund balance and amountWithdrawn to consider max limit capability")
      }
    }

    pub fun timeTravel(ageUp: UInt64) { 
      self.currentTime = self.currentTime + ageUp
    }

    pub fun readlimit(): UFix64 { return self.limit }

    pub fun readAmountWithdrawn(): UFix64 { return self.amountWithdrawn }

    pub fun readFundBalance(): UFix64 {
      let ref = self.withdrawer.borrow() ?? panic("Could not borrow receiver")
      return ref.balance
    }

    pub fun readCurrentTime(): UInt64 { return self.currentTime }

    init(adultTime: UInt64, withdrawCap: Capability<&FlowToken.Vault{FungibleToken.Provider, FungibleToken.Balance}>) {
      self.adultTime = adultTime
      self.currentTime = 0
      self.limit = 0.0 
      // this matters after adulthood (keeping track of fund value at adulthood)
      self.amountWithdrawn = 0.0 
      
      self.withdrawer = withdrawCap 
    }
  }

  access(all) resource ChildClient {
    access(self) var gateway: Capability<&EducationFund.VaultGateway{EducationFund.Child}>?

    init() {
      self.gateway = nil
    }

    pub fun addCapability(_ cap: Capability<&EducationFund.VaultGateway{EducationFund.Child}>) {
      pre {
          cap.check() : "Invalid gateway capablity"
          self.gateway == nil : "Gateway already set"
      }
      self.gateway = cap
    }

    pub fun retrieveGateway(): Capability<&EducationFund.VaultGateway{EducationFund.Child}>? {
      return self.gateway
    }
  }

  access(all) resource ParentClient {
    access(self) var gateway: Capability<&EducationFund.VaultGateway{EducationFund.Parent}>?

    init() {
      self.gateway = nil
    }

    pub fun addCapability(_ cap: Capability<&EducationFund.VaultGateway{EducationFund.Parent}>) {
      pre {
          cap.check() : "Invalid gateway capablity"
          self.gateway == nil : "Gateway already set"
      }
      self.gateway = cap
    }

    pub fun retrieveGateway(): Capability<&EducationFund.VaultGateway{EducationFund.Parent}>? {
      return self.gateway
    }
  }
  
  access(all) fun createChildClient(): @ChildClient {
    return <- create ChildClient()   
  }

  access(all) fun createParentClient(): @ParentClient {
    return <- create ParentClient()   
  }

  init() {
    // hardcoded here as playground doesn't allow passing in parameters when deploying contracts
    // if opting for no parameter option, would typically use UInt64(getCurrentBlock().timestamp) + 567710000
    // keep in mind 567710000 = approx 18 yrs in seconds
    // however playground doesn't support getting current block's timestamp
    let adultTime = 18 as UInt64

    // Store created vault in the account storage
    self.account.save<@FungibleToken.Vault>(<-FlowToken.createEmptyVault(), to: /storage/MainVault)
    log("Empty Vault stored")

    // Create a Receiver capability to the Vault
    let ReceiverRef = self.account.link<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>(/public/MainReceiver, target: /storage/MainVault)
    
    // make sure not nil, or else, it exists at that path

    // Create a private Withdraw capability to the Vault
    let WithdrawRef = self.account.link<&FlowToken.Vault{FungibleToken.Provider, FungibleToken.Balance}>(/private/ChildWithdraw, target: /storage/MainVault)

    // make sure not nil, or else, it exists at that path

    log("References created")
    let Withdraw = self.account.getCapability<&FlowToken.Vault{FungibleToken.Provider, FungibleToken.Balance}>(/private/ChildWithdraw)

    self.account.save<@EducationFund.VaultGateway>(<- create EducationFund.VaultGateway(adultTime, Withdraw), to: /storage/VaultGateway)
    self.account.link<&EducationFund.VaultGateway{EducationFund.Child}>(/private/Child, target: /storage/VaultGateway)
    self.account.link<&EducationFund.VaultGateway{EducationFund.Parent}>(/private/Parent, target: /storage/VaultGateway)

    self.account.link<&EducationFund.VaultGateway{EducationFund.ReadState}>(/public/ReadFundState, target: /storage/VaultGateway)
  }
}