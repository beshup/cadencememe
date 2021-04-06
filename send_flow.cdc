import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61

transaction(amount: UFix64, recipient: Address) {
  let sentVault: @FungibleToken.Vault

  prepare(signer: AuthAccount) {
    let myvault = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)

    self.sentVault <- myvault.withdraw(amount: amount)
  }

  execute {
    let receiverRef =  getAccount(recipient)
      .getCapability(/public/flowTokenReceiver)
      .borrow<&{FungibleToken.Receiver}>()
        ?? panic("failed to borrow reference to recipient vault")

    receiverRef.deposit(from: <-self.sentVault)
  }
}

