import Foundation

/// Text fields eligible for keyboard next/previous navigation on the signup form,
/// in on-screen order. Pickers and the DatePicker aren't included — they don't use
/// the software keyboard.
enum SignupField: Hashable {
  case firstName, lastName, email, zipCode, guardianEmail, password, confirmPassword, familyCode
}
