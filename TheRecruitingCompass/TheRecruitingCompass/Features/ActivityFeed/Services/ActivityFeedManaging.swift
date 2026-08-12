import Foundation

/// Service contract for fetching the raw data that powers the activity feed timeline.
///
/// Each method returns a different event type; `ActivityFeedViewModel` merges and sorts
/// them into a unified chronological list.
protocol ActivityFeedManaging: Sendable {
  /// Returns all interactions for the user, used to populate interaction events in the feed.
  func fetchInteractions(userId: String) async throws -> [Interaction]
  /// Returns all school status changes for the user, used to populate status-change events.
  func fetchStatusChanges(userId: String) async throws -> [SchoolStatusHistory]
  /// Returns document records for the user, used to populate document-upload events.
  func fetchDocuments(userId: String) async throws -> [DocumentRecord]
  /// Returns a map of school ID to display name for resolving school names within feed items.
  func fetchSchoolNames(schoolIds: [String]) async throws -> [String: String]
}
