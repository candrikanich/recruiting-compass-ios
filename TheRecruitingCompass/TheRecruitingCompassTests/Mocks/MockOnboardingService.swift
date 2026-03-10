import Foundation
@testable import TheRecruitingCompass

final class MockOnboardingService: OnboardingManaging, @unchecked Sendable {
  var isOnboardingCompleteResult = false
  var shouldThrowError = false
  var mockError: Error = NSError(domain: "MockOnboarding", code: 0)

  var isOnboardingCompleteCallCount = 0
  var completeOnboardingCallCount = 0
  var lastUserIdChecked: String?

  func isOnboardingComplete(userId: String) async throws -> Bool {
    isOnboardingCompleteCallCount += 1
    lastUserIdChecked = userId
    if shouldThrowError { throw mockError }
    return isOnboardingCompleteResult
  }

  func completeOnboarding(
    userId: String,
    assessment: OnboardingAssessment,
    startingPhase: String
  ) async throws {
    completeOnboardingCallCount += 1
    if shouldThrowError { throw mockError }
  }
}
