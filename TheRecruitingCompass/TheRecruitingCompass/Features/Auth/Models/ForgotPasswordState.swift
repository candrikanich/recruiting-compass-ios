import Foundation

enum ForgotPasswordState: Equatable {
  case form
  case sending
  case emailSent(submittedEmail: String)
  case error(message: String)
}
