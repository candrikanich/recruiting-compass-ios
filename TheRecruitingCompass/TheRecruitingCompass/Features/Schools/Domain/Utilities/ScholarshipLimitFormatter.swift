import Foundation

/// Pure selection/formatting for the College Data scholarship-limit reference
/// line. Mirrors web's `utils/scholarshipLimits.ts` exactly (branch order,
/// asymmetric sport/division case-normalization, capitalization).
enum ScholarshipLimitFormatter {
  /// Exact (sport, division) match only — a miss means no scholarship line
  /// renders, matching web's fail-open behavior for an empty/unseeded table.
  static func select(
    from limits: [ScholarshipLimit],
    sport: String?,
    division: String?
  ) -> ScholarshipLimit? {
    guard let sport, let division else { return nil }
    let normalizedSport = sport.lowercased()
    return limits.first { $0.sport.lowercased() == normalizedSport && $0.division == division }
  }

  /// "Athletic Scholarships: 11.7 equivalency (D1 Baseball)" — equivalency
  /// sports show the fractional scholarship count; head-count sports show a
  /// whole roster-spot count; `total` is the fallback when neither is set.
  static func line(for limit: ScholarshipLimit, sport: String, division: String) -> String {
    let detail = "(\(division) \(capitalize(sport)))"
    if let equivalency = limit.equivalency {
      return "Athletic Scholarships: \(format(equivalency)) equivalency \(detail)"
    }
    if let headCount = limit.headCount {
      return "Athletic Scholarships: \(headCount) head-count \(detail)"
    }
    if let total = limit.total {
      return "Athletic Scholarships: \(format(total)) total \(detail)"
    }
    return "Athletic Scholarships: see \(detail)"
  }

  private static func capitalize(_ value: String) -> String {
    guard let first = value.first else { return value }
    return first.uppercased() + value.dropFirst()
  }

  /// Matches JS's default number-to-string coercion (no trailing ".0").
  private static func format(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0
      ? String(Int(value))
      : String(value)
  }
}
