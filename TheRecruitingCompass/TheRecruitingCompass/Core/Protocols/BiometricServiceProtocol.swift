protocol BiometricServiceProtocol: AnyObject {
  func canEvaluateBiometrics() -> Bool
  func authenticate(reason: String) async throws
}
