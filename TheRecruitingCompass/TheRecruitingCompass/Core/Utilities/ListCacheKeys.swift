import Foundation

/// Centralized cache-key builders for list-screen `InMemoryCache` entries (audit
/// Phase 3.6). A list VM and every VM that creates/mutates its entity type must
/// agree on the exact same key string to invalidate correctly — defining them
/// once here removes the risk of a typo'd literal diverging between VMs.
enum ListCacheKeys {
  static func schools(familyUnitId: String) -> String { "schoolsList:\(familyUnitId)" }
  static func offers(userId: String) -> String { "offersList:\(userId)" }
  /// Interactions has two distinct fetch scopes (InteractionsListViewModel):
  /// parents see the whole family unit, athletes see only their own — cache
  /// each separately or a parent's cache read would leak into/from an
  /// athlete's narrower view, or vice versa. Any mutation site invalidates
  /// both, since it can't always tell which scope is currently cached.
  static func interactionsForFamily(familyUnitId: String) -> String { "interactionsList:family:\(familyUnitId)" }
  static func interactionsForAthlete(userId: String) -> String { "interactionsList:athlete:\(userId)" }
  static func coaches(familyUnitId: String) -> String { "coachesList:\(familyUnitId)" }
  static func documents(userId: String) -> String { "documentsList:\(userId)" }
  static func events(userId: String) -> String { "eventsList:\(userId)" }
  static func metrics(userId: String) -> String { "metricsList:\(userId)" }
  static func notifications(userId: String) -> String { "notificationsList:\(userId)" }
  static func tasks(athleteId: String, gradeLevel: Int) -> String { "tasksList:\(athleteId):\(gradeLevel)" }
  static func activities(userId: String) -> String { "activitiesList:\(userId)" }
}
