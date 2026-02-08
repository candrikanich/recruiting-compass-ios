import Foundation

struct PasswordResetConfig {
  let resendCooldownDuration: Int
  let successCountdownDuration: Int
  let timerInterval: TimeInterval

  static let `default` = PasswordResetConfig(
    resendCooldownDuration: 60,
    successCountdownDuration: 3,
    timerInterval: 1.0
  )
}
