import EducationFund from 0x03

pub fun main(): Int {
  let fundAccount = getAccount(0x03)

  let readState = fundAccount.getCapability<&EducationFund.VaultGateway{EducationFund.ReadState}>(/public/ReadFundState).borrow() ?? panic("Could not borrow")

  log("balance: ".concat(readState.readFundBalance().toString()))
  log("limit: ".concat(readState.readlimit().toString()))
  log("amountWithdrawn: ".concat(readState.readAmountWithdrawn().toString()))
  log("currentTime: ".concat(readState.readCurrentTime().toString()))

  return 1
}
