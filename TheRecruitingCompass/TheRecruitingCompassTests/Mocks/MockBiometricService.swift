@testable import TheRecruitingCompass

@MainActor
final class MockBiometricService: BiometricServiceProtocol {
  nonisolated deinit {}

  var canEvaluateResult = true
  var authenticateResult: Result<Void, Error> = .success(())
  var authenticateCallCount = 0

  func canEvaluateBiometrics() -> Bool {
    canEvaluateResult
  }

  func authenticate(reason: String) async throws {
    authenticateCallCount += 1
    try authenticateResult.get()
  }
}
