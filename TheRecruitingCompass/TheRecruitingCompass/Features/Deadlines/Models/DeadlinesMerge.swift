import Foundation

/// One cell in a month-grid calendar view. `date` is the local-timezone ISO
/// day; `isCurrentMonth` distinguishes spillover cells from the prior/next
/// month (rendered dimmed, still tappable).
struct CalendarDay: Identifiable, Equatable, Sendable {
  let date: String // ISO "YYYY-MM-DD"
  let dayNumber: Int
  let isCurrentMonth: Bool
  var id: String { date }
}

/// Pure merge/group/split logic for the unified Deadlines timeline. Swift
/// mirror of web `utils/deadlines.ts` (`mergeDeadlines`, `groupByMonth`,
/// `splitUpcomingPast`) — kept as static functions on plain data so it's
/// directly testable without a ViewModel or network.
enum DeadlinesMerge {
  private static let gridCalendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = .current
    cal.firstWeekday = 1 // Sunday
    return cal
  }()

  private static let isoDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.calendar = Calendar(identifier: .gregorian)
    f.timeZone = .current
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
  }()

  /// Builds a Sunday-start, 6-week (42-cell) month grid for `year`/`month`,
  /// spilling into the prior/next month to fill leading/trailing cells.
  /// Uses local `Calendar` day arithmetic throughout — never UTC/
  /// `toISOString` — to avoid the off-by-one at timezone boundaries that
  /// web's `buildCalendarGrid` was written to avoid.
  static func buildCalendarGrid(year: Int, month: Int) -> [CalendarDay] {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = 1
    guard let firstOfMonth = gridCalendar.date(from: components) else { return [] }

    let firstWeekday = gridCalendar.component(.weekday, from: firstOfMonth) // 1 = Sunday
    let leadingSpillover = firstWeekday - gridCalendar.firstWeekday
    guard let gridStart = gridCalendar.date(byAdding: .day, value: -leadingSpillover, to: firstOfMonth) else {
      return []
    }

    return (0..<42).compactMap { offset in
      guard let date = gridCalendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
      let cellMonth = gridCalendar.component(.month, from: date)
      let cellDay = gridCalendar.component(.day, from: date)
      return CalendarDay(
        date: isoDayFormatter.string(from: date),
        dayNumber: cellDay,
        isCurrentMonth: cellMonth == month
      )
    }
  }

  /// Buckets a unified list by ISO date, e.g. for a calendar day's dot
  /// indicators / tap-to-expand detail panel.
  static func groupByDate(_ deadlines: [UnifiedDeadline]) -> [String: [UnifiedDeadline]] {
    Dictionary(grouping: deadlines, by: \.date)
  }

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

  /// Filters a unified list by raw category key and/or a case-insensitive
  /// label search. `category: nil` and `search: ""` (after trimming) are
  /// both no-ops. Mirrors web's `filterDeadlines(deadlines, {category, search})`.
  static func filter(
    _ deadlines: [UnifiedDeadline],
    category: String?,
    search: String
  ) -> [UnifiedDeadline] {
    let trimmedSearch = search.trimmingCharacters(in: .whitespacesAndNewlines)
    return deadlines.filter { deadline in
      if let category, deadline.category != category { return false }
      if !trimmedSearch.isEmpty, !deadline.label.localizedCaseInsensitiveContains(trimmedSearch) { return false }
      return true
    }
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
