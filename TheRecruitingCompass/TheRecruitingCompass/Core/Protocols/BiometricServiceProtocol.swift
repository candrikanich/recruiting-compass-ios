/// Abstracts Face ID / Touch ID evaluation, enabling dependency injection and mock-based testing.
protocol BiometricServiceProtocol: AnyObject {
  /// Returns `true` if the device supports biometrics and the user is enrolled.
  func canEvaluateBiometrics() -> Bool
  /// Presents the system biometric prompt with the given `reason` string.
  /// - Throws: `BiometricError` if authentication fails, is unavailable, or is cancelled.
  func authenticate(reason: String) async throws
}
