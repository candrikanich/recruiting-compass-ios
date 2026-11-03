import Foundation

/// Service contract for fetching the raw data that powers the activity feed timeline.
///
/// Each method returns a different event type; `ActivityFeedViewModel` merges and sorts
/// them into a unified chronological list.
protocol ActivityFeedManaging: Sendable {
  /// Returns the interactions logged by anyone in the family, used to populate interaction events.
  func fetchInteractions(familyUnitId: String) async throws -> [Interaction]
  /// Returns status changes on the family's schools, used to populate status-change events.
  func fetchStatusChanges(familyUnitId: String) async throws -> [SchoolStatusHistory]
  /// Returns the family's document records, used to populate document-upload events.
  func fetchDocuments(familyUnitId: String) async throws -> [DocumentRecord]
  /// Returns a map of school ID to display name for resolving school names within feed items.
  func fetchSchoolNames(schoolIds: [String]) async throws -> [String: String]
}
