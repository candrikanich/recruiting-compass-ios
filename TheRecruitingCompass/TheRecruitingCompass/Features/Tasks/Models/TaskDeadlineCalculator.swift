import Foundation

/// Computes a task's deadline date from the athlete's graduation year and the
/// task template's `deadline_offset_months`, matching the web server's
/// `computeTaskDeadline` (server/utils/taskDeadlines.ts).
///
/// The deadline is anchored to **June 1 of the graduation year** and moved
/// `offsetMonths` months earlier; the day is always pinned to the 1st. Returns
/// nil when either input is missing, so callers render no deadline badge —
/// identical to the web behavior.
enum TaskDeadlineCalculator {
  /// June, 1-indexed. Mirrors web `GRADUATION_ANCHOR_MONTH`.
  private static let graduationAnchorMonth = 6

  static func deadlineDate(
    graduationYear: Int?,
    offsetMonths: Int?,
    calendar: Calendar = .current
  ) -> Date? {
    guard let graduationYear, let offsetMonths else { return nil }

    let anchorAbsMonth = graduationYear * 12 + (graduationAnchorMonth - 1)
    let targetAbsMonth = anchorAbsMonth - offsetMonths
    let year = Int((Double(targetAbsMonth) / 12.0).rounded(.down))
    let month = (targetAbsMonth % 12) + 1

    return calendar.date(from: DateComponents(year: year, month: month, day: 1))
  }
}
