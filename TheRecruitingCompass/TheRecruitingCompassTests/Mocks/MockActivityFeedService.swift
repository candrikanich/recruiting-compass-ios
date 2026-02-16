import Foundation
@testable import TheRecruitingCompass

final class MockActivityFeedService: ActivityFeedManaging, @unchecked Sendable {
  // MARK: - Stubbed Data

  var mockInteractions: [Interaction] = []
  var mockStatusChanges: [SchoolStatusHistory] = []
  var mockDocuments: [DocumentRecord] = []
  var mockSchoolNames: [String: String] = [:]

  // MARK: - Error Flags

  var shouldThrowOnInteractions = false
  var shouldThrowOnStatusChanges = false
  var shouldThrowOnDocuments = false
  var shouldThrowOnSchoolNames = false

  // MARK: - Call Counts

  var fetchInteractionsCallCount = 0
  var fetchStatusChangesCallCount = 0
  var fetchDocumentsCallCount = 0
  var fetchSchoolNamesCallCount = 0

  // MARK: - Captured Arguments

  var lastFetchInteractionsUserId: String?
  var lastFetchStatusChangesUserId: String?
  var lastFetchDocumentsUserId: String?
  var lastFetchSchoolNamesIds: [String]?

  // MARK: - ActivityFeedManaging

  func fetchInteractions(userId: String) async throws -> [Interaction] {
    fetchInteractionsCallCount += 1
    lastFetchInteractionsUserId = userId
    if shouldThrowOnInteractions {
      throw NSError(
        domain: "MockActivityFeed",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Mock interactions fetch error"]
      )
    }
    return mockInteractions
  }

  func fetchStatusChanges(userId: String) async throws -> [SchoolStatusHistory] {
    fetchStatusChangesCallCount += 1
    lastFetchStatusChangesUserId = userId
    if shouldThrowOnStatusChanges {
      throw NSError(
        domain: "MockActivityFeed",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Mock status changes fetch error"]
      )
    }
    return mockStatusChanges
  }

  func fetchDocuments(userId: String) async throws -> [DocumentRecord] {
    fetchDocumentsCallCount += 1
    lastFetchDocumentsUserId = userId
    if shouldThrowOnDocuments {
      throw NSError(
        domain: "MockActivityFeed",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Mock documents fetch error"]
      )
    }
    return mockDocuments
  }

  func fetchSchoolNames(schoolIds: [String]) async throws -> [String: String] {
    fetchSchoolNamesCallCount += 1
    lastFetchSchoolNamesIds = schoolIds
    if shouldThrowOnSchoolNames {
      throw NSError(
        domain: "MockActivityFeed",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "Mock school names fetch error"]
      )
    }
    return mockSchoolNames
  }

  // MARK: - Reset

  func reset() {
    mockInteractions = []
    mockStatusChanges = []
    mockDocuments = []
    mockSchoolNames = [:]
    shouldThrowOnInteractions = false
    shouldThrowOnStatusChanges = false
    shouldThrowOnDocuments = false
    shouldThrowOnSchoolNames = false
    fetchInteractionsCallCount = 0
    fetchStatusChangesCallCount = 0
    fetchDocumentsCallCount = 0
    fetchSchoolNamesCallCount = 0
    lastFetchInteractionsUserId = nil
    lastFetchStatusChangesUserId = nil
    lastFetchDocumentsUserId = nil
    lastFetchSchoolNamesIds = nil
  }
}
