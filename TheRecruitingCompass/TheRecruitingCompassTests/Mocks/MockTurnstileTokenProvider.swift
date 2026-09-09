import Foundation
@testable import TheRecruitingCompass

@MainActor
final class MockTurnstileTokenProvider: TurnstileTokenProviding {
  var tokenToReturn = "mock-turnstile-token"
  var shouldThrowError = false
  var errorToThrow: Error = AuthError.captchaFailed
  var getTokenCallCount = 0

  func getToken() async throws -> String {
    getTokenCallCount += 1
    if shouldThrowError { throw errorToThrow }
    return tokenToReturn
  }
}
