import Foundation

protocol ActivityFeedManaging: Sendable {
  func fetchInteractions(userId: String) async throws -> [Interaction]
  func fetchStatusChanges(userId: String) async throws -> [SchoolStatusHistory]
  func fetchDocuments(userId: String) async throws -> [DocumentRecord]
  func fetchSchoolNames(schoolIds: [String]) async throws -> [String: String]
}
