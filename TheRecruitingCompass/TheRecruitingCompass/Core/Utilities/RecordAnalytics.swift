import Foundation

/// `school_added` / `coach_added`, matching web. Called from the services that insert the rows, after the
/// insert succeeds, so every UI path (and onboarding) is counted once and a failed insert is never counted.
enum RecordAnalytics {
  /// A school with no division omits the property rather than sending an empty value, as web does.
  static func schoolAdded(division: String?) {
    var properties: [String: Any] = [:]
    if let division, !division.isEmpty { properties["division"] = division }
    Analytics.capture("school_added", properties: properties)
  }

  static func coachAdded() {
    Analytics.capture("coach_added")
  }
}
