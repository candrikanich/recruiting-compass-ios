import Foundation
@testable import TheRecruitingCompass

final class MockNuxProgressService: NuxProgressManaging, @unchecked Sendable {
  var stubbedProgress: NuxProgress = .empty
  var shouldThrowOnFetch = false
  var shouldThrowOnSave = false
  var mockError: Error = NSError(domain: "MockNuxProgress", code: 0)

  private(set) var fetchCallCount = 0
  private(set) var saveCallCount = 0
  private(set) var lastSavedProgress: NuxProgress?
  private(set) var lastSavedUserId: String?

  func fetchNuxProgress(userId: String) async throws -> NuxProgress {
    fetchCallCount += 1
    if shouldThrowOnFetch { throw mockError }
    return stubbedProgress
  }

  func saveNuxProgress(userId: String, progress: NuxProgress) async throws {
    saveCallCount += 1
    lastSavedUserId = userId
    lastSavedProgress = progress
    if shouldThrowOnSave { throw mockError }
  }
}
