import Foundation

/// Canonical ordering for recruiting-timeline task lists, shared by the Timeline
/// phase cards and the grade-level Tasks screen. Kept byte-identical to the web
/// `compareTimelineTasks` comparator (`utils/taskSort.ts`) so a parent on iOS and
/// a player on web see the same task order within a phase.
///
/// Keys, in priority order:
///   1. incomplete before completed
///   2. actionable before locked (incomplete prerequisites)
///   3. required before optional
///   4. deadline ascending, no-deadline last
///   5. category rank academic > recruiting > athletic > exposure > mindset, unknown last
///   6. title A–Z (deterministic tiebreak)
enum TimelineTaskSort {

  /// Lower rank sorts first. Mirrors web `CATEGORY_PRIORITY` (academic highest).
  static func categoryRank(_ category: String) -> Int {
    switch category {
    case "academic": return 0
    case "recruiting": return 1
    case "athletic": return 2
    case "exposure": return 3
    case "mindset": return 4
    default: return 5
    }
  }

  static func sorted(_ tasks: [TaskWithStatus]) -> [TaskWithStatus] {
    tasks.sorted { lhs, rhs in
      let lDone = lhs.effectiveStatus == .completed
      let rDone = rhs.effectiveStatus == .completed
      if lDone != rDone { return !lDone }

      if lhs.isLocked != rhs.isLocked { return !lhs.isLocked }

      if lhs.required != rhs.required { return lhs.required }

      let lDeadline = lhs.deadlineDate ?? .distantFuture
      let rDeadline = rhs.deadlineDate ?? .distantFuture
      if lDeadline != rDeadline { return lDeadline < rDeadline }

      let lCategory = categoryRank(lhs.category)
      let rCategory = categoryRank(rhs.category)
      if lCategory != rCategory { return lCategory < rCategory }

      return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
  }
}
