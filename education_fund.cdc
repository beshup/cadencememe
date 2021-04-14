import FungibleToken from 0x01
import FlowToken from 0x02

access(all) contract EducationFund {
  pub resource interface Child {
    access(contract) adultTime: UInt64

    pub fun withdraw(amount: UFix64, currentTime: UInt64): @FungibleToken.Vault {
      pre {
        currentTime > self.adultTime: "Child has to be adult to withdraw"
      }
      post {
        // `result` refers to the return value
        result.balance == amount:
          "Withdrawal amount must be the same as the balance of the withdrawn Vault"
      }
    }
  }

  pub resource interface Parent {
    access(contract) let adultTime: UInt64

    pub fun deposit(from: @FungibleToken.Vault, currentTime: UInt64) {
      pre {
        currentTime < self.adultTime: "Cannot deposit after child reaches adulthood"
      }
    }
    pub fun increaseLimit(limitIncrement: UFix64, currentTime: UInt64) {
      pre {
        currentTime > self.adultTime: "Cannot increase limit before child is adult"
      }
    }
  }

  pub resource interface ReadState {
    pub fun readlimit(): UFix64
    pub fun readAmountWithdrawn(): UFix64
    pub fun readFundBalance(): UFix64
  }


  access(all) resource VaultGateway: Child, Parent, ReadState {
    // assume times stored as unix timestamp (client handles conversion) 
    access(contract) let adultTime: UInt64
    access(self) var limit: UFix64
    access(self) var amountWithdrawn: UFix64

    access(self) var withdrawer: Capability<&FlowToken.Vault{FungibleToken.Provider, FungibleToken.Balance}>
    access(self) var receiver: Capability<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>

    pub fun deposit(from: @FungibleToken.Vault, currentTime: UInt64) {
      let ref = self.receiver.borrow() ?? panic("Could not borrow receiver")
      ref.deposit(from: <- from)
    } 

    pub fun withdraw(amount: UFix64, currentTime: UInt64): @FungibleToken.Vault {
      let ref = self.withdrawer.borrow() ?? panic("Could not borrow withdrawer")
      if ((self.amountWithdrawn + amount < self.limit) && (amount < ref.balance)) {
        self.amountWithdrawn = self.amountWithdrawn + amount
        return <- ref.withdraw(amount: amount)
      } 

      return <- FlowToken.createEmptyVault()
    } 

    pub fun increaseLimit(limitIncrement: UFix64, currentTime: UInt64) {
      let ref = self.receiver.borrow() ?? panic("Could not borrow receiver")
      let proposedLimit = self.limit + limitIncrement

      if (proposedLimit <= self.amountWithdrawn + ref.balance) {
        self.limit = self.limit + limitIncrement
      } 
      else {
        panic("Limit exceeds withdraw capability for child, see fund balance and amountWithdrawn to consider max limit capability")
      }
    }

    pub fun readlimit(): UFix64 {
      return self.limit
    }

    pub fun readAmountWithdrawn(): UFix64 {
      return self.amountWithdrawn
    }

    pub fun readFundBalance(): UFix64 {
      let ref = self.receiver.borrow() ?? panic("Could not borrow receiver")
      return ref.balance
    }

    init(adultTime: UInt64, withdrawCap: Capability<&FlowToken.Vault{FungibleToken.Provider, FungibleToken.Balance}>, receiverCap: Capability<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>) {
      self.adultTime = adultTime
      self.limit = 0.0 
      // this matters after adulthood (keeping track of fund value at adulthood)
      self.amountWithdrawn = 0.0 
      
      self.withdrawer = withdrawCap 
      self.receiver = receiverCap
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

  init(adultTime: UInt64) {
    // Store created vault in the account storage
    self.account.save<@FungibleToken.Vault>(<-FlowToken.createEmptyVault(), to: /storage/MainVault)
    log("Empty Vault stored")

    // Create a private Receiver capability to the Vault
    let ReceiverRef = self.account.link<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>(/private/Receiver, target: /storage/MainVault)
    
    // make sure not nil, or else, it exists at that path

    // Create a private Withdraw capability to the Vault
    let WithdrawRef = self.account.link<&FlowToken.Vault{FungibleToken.Provider, FungibleToken.Balance}>(/private/Withdraw, target: /storage/MainVault)

    // make sure not nil, or else, it exists at that path

    log("References created")
    let Receiver = self.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>(/private/ParentReceiver)
    let Withdraw = self.account.getCapability<&FlowToken.Vault{FungibleToken.Provider, FungibleToken.Balance}>(/private/ChildWithdraw)

    self.account.save<@EducationFund.VaultGateway>(<- create EducationFund.VaultGateway(adultTime, Withdraw, Receiver), to: /storage/VaultGateway)
    self.account.link<&EducationFund.VaultGateway{EducationFund.Child}>(/private/Child, target: /storage/VaultGateway)
    self.account.link<&EducationFund.VaultGateway{EducationFund.Parent}>(/private/Parent, target: /storage/VaultGateway)

    self.account.link<&EducationFund.VaultGateway{EducationFund.ReadState}>(/public/ReadFundState, target: /storage/VaultGateway)
  }
}