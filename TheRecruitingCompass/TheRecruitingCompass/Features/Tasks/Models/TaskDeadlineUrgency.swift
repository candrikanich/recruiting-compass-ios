import Foundation
import SwiftUI

/// Deadline urgency for tasks. Computed from deadline date: overdue/<0 days → critical; ≤7 → urgent; ≤14 → upcoming; else future; nil → none.
enum TaskDeadlineUrgency: String, Codable, CaseIterable, Sendable {
  case critical
  case urgent
  case upcoming
  case future
  case none

  var label: String? {
    switch self {
    case .critical: return "Overdue / Due Soon"
    case .urgent: return "Due This Week"
    case .upcoming: return "Due In 2 Weeks"
    case .future, .none: return nil
    }
  }

  var color: Color {
    switch self {
    case .critical: return .errorRed
    case .urgent: return Color(hex: "F59E0B")
    case .upcoming, .future: return .secondary
    case .none: return .secondary
    }
  }

  /// Computes urgency from a deadline date and optional reference date (default: today).
  static func from(deadline: Date?, reference: Date = Date()) -> TaskDeadlineUrgency {
    guard let deadline else { return .none }
    let calendar = Calendar.current
    let startRef = calendar.startOfDay(for: reference)
    let startDeadline = calendar.startOfDay(for: deadline)
    guard let days = calendar.dateComponents([.day], from: startRef, to: startDeadline).day else { return .none }
    if days < 0 { return .critical }
    if days <= 7 { return .urgent }
    if days <= 14 { return .upcoming }
    return .future
  }
}
