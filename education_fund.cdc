import FungibleToken from 0x01
import FlowToken from 0x02

access(all) contract EducationFund {
  pub resource interface Child {
    pub fun withdraw(amount: UFix64, currentTime: UInt64): @FungibleToken.Vault {
      post {
        // `result` refers to the return value
        result.balance == amount:
          "Withdrawal amount must be the same as the balance of the withdrawn Vault"
      }
    }
  }

  pub resource interface Parent {
    pub fun deposit(from: @FungibleToken.Vault)
    pub fun setLimit(limitIncreaseTime: UInt64)
  }


  access(all) resource VaultGateway: Child, Parent {
    // assume times stored as unix timestamp (client handles conversion) 
    pub let adultTime: UInt64
    pub var limitIncreaseTime: UInt64
    pub var limit: UFix64
    pub var amountDepositedByAdulthood: UFix64

    access(self) var withdrawer: Capability<&FlowToken.Vault{FungibleToken.Provider, FungibleToken.Balance}>
    access(self) var receiver: Capability<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>

    pub fun deposit(from: @FungibleToken.Vault) {
      let ref = self.receiver.borrow() ?? panic("Could not borrow receiver")
      ref.deposit(from: <- from)
    } 

    pub fun withdraw(amount: UFix64, currentTime: UInt64): @FungibleToken.Vault {
      let ref = self.withdrawer.borrow() ?? panic("Could not borrow withdrawer")
      if (currentTime > self.adultTime && (self.amountDepositedByAdulthood - self.limit) < (ref.balance - amount)) {
        return <- ref.withdraw(amount: amount)
      } 

      return <- FlowToken.createEmptyVault()
    } 

    pub fun setLimit(limitIncreaseTime: UInt64) {

    }

    init(adultTime: UInt64, withdrawCap: Capability<&FlowToken.Vault{FungibleToken.Provider, FungibleToken.Balance}>, receiverCap: Capability<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>) {
      self.adultTime = adultTime
      // max UInt64
      self.limitIncreaseTime = 0xFFFFFFFFFFFFFFFF
      self.limit = 0.0 
      // this matters after adulthood (keeping track of fund value at adulthood)
      self.amountDepositedByAdulthood = 0.0 
      
      self.withdrawer = withdrawCap 
      self.receiver = receiverCap
    }
  }

  access(all) resource ChildClient {
    access(self) var withdrawer: Capability<&EducationFund.VaultGateway{EducationFund.Child}>?

    init() {
      self.withdrawer = nil
    }

    pub fun addCapability(_ cap: Capability<&EducationFund.VaultGateway{EducationFund.Child}>) {
      pre {
          cap.check() : "Invalid withdrawer capablity"
          self.withdrawer == nil : "Withdraw already set"
      }
      self.withdrawer = cap
    }
  }

  access(all) resource ParentClient {
    access(self) var receiver: Capability<&EducationFund.VaultGateway{EducationFund.Parent}>?

    init() {
      self.receiver = nil
    }

    pub fun addCapability(_ cap: Capability<&EducationFund.VaultGateway{EducationFund.Parent}>) {
      pre {
          cap.check() : "Invalid withdrawer capablity"
          self.receiver == nil : "Withdraw already set"
      }
      self.receiver = cap
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
  }
}