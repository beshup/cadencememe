import EducationFund from 0x03

pub fun main(): Int {
  let fundAccount = getAccount(0x03)

  let readState = fundAccount.getCapability<&EducationFund.VaultGateway{EducationFund.ReadState}>(/public/ReadFundState).borrow() ?? panic("Could not borrow")

  log("balance: ")
  log(readState.readFundBalance().toString())
  log("\n")

  log("limit: ")
  log(readState.readlimit().toString())
  log("\n")

  log("amountWithdrawn: ")
  log(readState.readAmountWithdrawn().toString())
  log("\n")

  return 1
}
