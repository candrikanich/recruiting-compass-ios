import Foundation
@testable import TheRecruitingCompass

final class MockHelpFeedbackService: HelpFeedbackManaging, @unchecked Sendable {
  var shouldThrowOnSubmit = false
  var errorToThrow: Error = NSError(domain: "MockHelpFeedback", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])

  var submitFeedbackCallCount = 0
  var lastPage: String?
  var lastHelpful: Bool?
  var lastUserId: String?

  func submitFeedback(page: String, helpful: Bool, userId: String) async throws {
    submitFeedbackCallCount += 1
    lastPage = page
    lastHelpful = helpful
    lastUserId = userId
    if shouldThrowOnSubmit { throw errorToThrow }
  }
}
