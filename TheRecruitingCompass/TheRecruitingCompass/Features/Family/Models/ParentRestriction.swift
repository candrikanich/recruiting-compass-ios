import Foundation

/// Single source for what a parent sees when viewing an athlete. Parents may add notes, tasks and
/// documents (family data is collaborative, product decision 2026-11-03); the one action that stays
/// with the athlete is completing their tasks. Every restricted control explains itself with this copy.
enum ParentRestriction {
  /// Used when a family has no resolvable athlete name yet.
  static let fallbackAthleteName = "your athlete"

  static func completeTaskMessage(athleteName: String) -> String {
    "Only \(athleteName) can mark tasks complete. You can still add notes and documents."
  }

  static func bannerDetail(athleteName: String) -> String {
    "Viewing \(athleteName)'s tasks. Edits you make here are shared with the whole family."
  }
}
