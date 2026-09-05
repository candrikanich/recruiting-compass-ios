import SwiftUI

/// Where a `UnifiedDeadline` came from — a user-created `user_deadlines` row
/// (editable, deletable) or a system NCAA-calendar `CalendarMilestone`
/// (read-only). Mirrors web `UnifiedDeadline.source` in `types/deadline.ts`.
enum DeadlineSource: String, Sendable, Equatable {
  case user
  case system
}

/// One row in the merged Deadlines timeline — either a user deadline or a
/// system NCAA-calendar milestone, normalized to a single shape so the list
/// view/grouping/sorting logic doesn't need to branch on origin. Swift mirror
/// of web `UnifiedDeadline` (`types/deadline.ts`).
struct UnifiedDeadline: Identifiable, Equatable, Sendable {
  let id: String
  let label: String
  let date: String // ISO "YYYY-MM-DD"
  /// Raw category key — either a `DeadlineCategory.rawValue` (source == .user)
  /// or a `MilestoneType.rawValue` (source == .system).
  let category: String
  let source: DeadlineSource
  let description: String?
  let url: String?
  /// The underlying user row, present only when `source == .user` — needed
  /// for the swipe-to-delete action, which only applies to user deadlines.
  let userDeadline: Deadline?

  var isRemovable: Bool { userDeadline != nil }

  var sourceBadge: String {
    switch source {
    case .user:   return String(localized: "My Deadline")
    case .system: return String(localized: "NCAA Calendar")
    }
  }

  var categoryDisplayName: String {
    switch source {
    case .user:
      return DeadlineCategory(rawValue: category)?.displayName ?? category.capitalized
    case .system:
      return MilestoneType(rawValue: category)?.displayName ?? category.capitalized
    }
  }

  var icon: String {
    switch source {
    case .user:
      return DeadlineCategory(rawValue: category)?.icon ?? "tag"
    case .system:
      return MilestoneType(rawValue: category)?.icon ?? "calendar"
    }
  }

  var color: Color {
    switch source {
    case .user:
      return DeadlineCategory(rawValue: category)?.color ?? .gray
    case .system:
      return .indigo
    }
  }
}

private extension MilestoneType {
  var displayName: String {
    switch self {
    case .test:       return String(localized: "Test")
    case .deadline:    return String(localized: "Deadline")
    case .ncaaPeriod:  return String(localized: "NCAA Period")
    case .application: return String(localized: "Application")
    case .signing:     return String(localized: "Signing")
    }
  }

  var icon: String {
    switch self {
    case .test:        return "pencil.and.list.clipboard"
    case .deadline:     return "clock.badge.exclamationmark"
    case .ncaaPeriod:   return "calendar.badge.clock"
    case .application:  return "envelope"
    case .signing:      return "signature"
    }
  }
}
