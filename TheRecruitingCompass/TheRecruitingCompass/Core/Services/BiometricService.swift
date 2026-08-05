import LocalAuthentication

final class BiometricService: BiometricServiceProtocol {
  nonisolated deinit {}

  func canEvaluateBiometrics() -> Bool {
    let context = LAContext()
    var error: NSError?
    return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
  }

  func authenticate(reason: String) async throws {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      throw BiometricError.notAvailable
    }
    do {
      let success = try await context.evaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        localizedReason: reason
      )
      if !success { throw BiometricError.failed }
    } catch let laError as LAError {
      switch laError.code {
      case .biometryLockout:
        throw BiometricError.lockout
      case .userCancel, .appCancel, .systemCancel:
        throw BiometricError.cancelled
      case .biometryNotAvailable, .biometryNotEnrolled:
        throw BiometricError.notAvailable
      default:
        throw BiometricError.failed
      }
    }
  }
}
