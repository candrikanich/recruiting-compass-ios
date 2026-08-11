import Foundation

/// Graduation year and grade-level helpers. Aligns with web: allowed years = current year through current+4 (no players under 13).
enum GradeLevelHelper {
  /// Allowed graduation years for pickers: current year through current+4 (5 years). Matches web; excludes years that would imply under-13.
  static var allowedGraduationYears: [Int] {
    let year = Calendar.current.component(.year, from: Date.now)
    return Array(year...(year + 4))
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
}
