import Foundation

/// Pure merge/group/split logic for the unified Deadlines timeline. Swift
/// mirror of web `utils/deadlines.ts` (`mergeDeadlines`, `groupByMonth`,
/// `splitUpcomingPast`) — kept as static functions on plain data so it's
/// directly testable without a ViewModel or network.
enum DeadlinesMerge {
  /// Converts user deadlines + system milestones into one sorted, deduped
  /// `UnifiedDeadline` list. System items come first so they win ties when a
  /// user deadline coincides with a system milestone on the same date/label
  /// (mirrors web's dedup, which concatenates system+user before deduping).
  static func unify(userDeadlines: [Deadline], milestones: [CalendarMilestone]) -> [UnifiedDeadline] {
    let systemItems = milestones.map { milestone in
      UnifiedDeadline(
        id: "system-\(milestone.date)-\(milestone.title)",
        label: milestone.title,
        date: milestone.date,
        category: milestone.type.rawValue,
        source: .system,
        description: milestone.description,
        url: milestone.url,
        userDeadline: nil
      )
    }
    let userItems = userDeadlines.map { deadline in
      UnifiedDeadline(
        id: "user-\(deadline.id)",
        label: deadline.label,
        date: deadline.deadlineDate,
        category: deadline.category.rawValue,
        source: .user,
        description: nil,
        url: nil,
        userDeadline: deadline
      )
    }

    var seen = Set<String>()
    let deduped = (systemItems + userItems).filter {
      seen.insert("\($0.date)|\($0.label)|\($0.source.rawValue)").inserted
    }
    return deduped.sorted { $0.date < $1.date }
  }

  /// Groups an already-sorted-ascending list by `"YYYY-MM"` month key,
  /// preserving first-seen month order.
  static func groupByMonth(_ deadlines: [UnifiedDeadline]) -> [(month: String, items: [UnifiedDeadline])] {
    var order: [String] = []
    var byMonth: [String: [UnifiedDeadline]] = [:]
    for deadline in deadlines {
      let key = String(deadline.date.prefix(7))
      if byMonth[key] == nil { order.append(key) }
      byMonth[key, default: []].append(deadline)
    }
    return order.map { (month: $0, items: byMonth[$0] ?? []) }
  }

  /// Splits into upcoming (`date >= today`) and past (`date < today`), each
  /// keeping the input's relative order.
  static func splitUpcomingPast(
    _ deadlines: [UnifiedDeadline],
    today: String
  ) -> (upcoming: [UnifiedDeadline], past: [UnifiedDeadline]) {
    var upcoming: [UnifiedDeadline] = []
    var past: [UnifiedDeadline] = []
    for deadline in deadlines {
      if deadline.date >= today {
        upcoming.append(deadline)
      } else {
        past.append(deadline)
      }
    }
    return (upcoming, past)
  }
}
