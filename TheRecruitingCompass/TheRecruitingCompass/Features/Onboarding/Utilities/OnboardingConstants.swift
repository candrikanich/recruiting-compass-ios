import Foundation

/// Constants for onboarding flow. Mirrors web onboarding index.vue.
enum OnboardingConstants {
  static let totalSteps = 5

  static let commonSports: [String] = [
    "Baseball", "Basketball", "Football", "Soccer", "Volleyball", "Softball",
    "Track & Field", "Swimming", "Cross Country", "Tennis", "Golf", "Lacrosse",
    "Field Hockey", "Ice Hockey", "Wrestling", "Rowing", "Water Polo",
    "Gymnastics", "Beach Volleyball"
  ]

  /// Canonical sport-scoped positions (mirrors web) plus an "Other" fallback for
  /// the "Other" sport option. See `CanonicalPositions`.
  static let sportPositions: [String: [String]] =
    CanonicalPositions.bySport.merging(["Other": ["Other"]]) { current, _ in current }

  static var graduationYears: [Int] {
    GradeLevelHelper.allowedGraduationYears
  }
}
