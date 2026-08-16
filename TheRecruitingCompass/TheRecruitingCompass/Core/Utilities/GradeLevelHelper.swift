import Foundation

/// Graduation year and grade-level helpers. Aligns with web `getGraduationYearOptions()`: current year through current+5.
enum GradeLevelHelper {
  /// Allowed graduation years for pickers: current year through current+5 (6 years). Matches web canonical
  /// `utils/graduationYears.ts`; the +5 upper bound lets rising 8th graders (13+) pick their class. Age
  /// eligibility is enforced separately by the 13+ COPPA gate, not by this range.
  static var allowedGraduationYears: [Int] {
    let year = Calendar.current.component(.year, from: Date.now)
    return Array(year...(year + 5))
  }

  /// Returns current grade (9–12) for the given graduation year, using a July 1 roll pivot.
  /// Formula: 12 - (graduationYear - schoolYearEndYear), clamped to 9...12.
  static func calculateCurrentGrade(graduationYear: Int) -> Int {
    calculateCurrentGrade(graduationYear: graduationYear, referenceDate: Date.now)
  }

  /// Same as above with an explicit reference date (for testing month boundaries).
  ///
  /// July 1 roll pivot: during summer (July–August) an athlete is treated as the grade they are
  /// rising INTO, matching the recruiting cycle (e.g. NCAA D1 contact opens Aug 1 before junior
  /// year — a rising junior is recruited as a junior). June still counts the just-finished grade.
  /// Matches web `calculateCurrentGrade` in utils/gradeHelpers.ts.
  static func calculateCurrentGrade(graduationYear: Int, referenceDate: Date) -> Int {
    let calendar = Calendar.current
    let year = calendar.component(.year, from: referenceDate)
    let month = calendar.component(.month, from: referenceDate)
    let schoolYearEndYear = month >= 7 ? year + 1 : year
    let grade = 12 - (graduationYear - schoolYearEndYear)
    return min(12, max(9, grade))
  }

  /// Canonical graduation date for a class year: June 1 of the graduation year.
  /// Whole-day granularity is all the countdown needs, so the day-of-month is a
  /// deliberate, stable convention rather than a real per-school commencement date.
  static func graduationDate(graduationYear: Int, calendar: Calendar = .current) -> Date? {
    calendar.date(from: DateComponents(year: graduationYear, month: 6, day: 1))
  }

  /// Whole days from `referenceDate` to graduation (June 1 of `graduationYear`).
  /// Returns nil once graduation has passed, so callers show "--" instead of a negative count.
  static func daysUntilGraduation(
    graduationYear: Int,
    referenceDate: Date = .now,
    calendar: Calendar = .current
  ) -> Int? {
    guard let gradDate = graduationDate(graduationYear: graduationYear, calendar: calendar) else { return nil }
    let start = calendar.startOfDay(for: referenceDate)
    let end = calendar.startOfDay(for: gradDate)
    guard let days = calendar.dateComponents([.day], from: start, to: end).day, days >= 0 else { return nil }
    return days
  }
}
