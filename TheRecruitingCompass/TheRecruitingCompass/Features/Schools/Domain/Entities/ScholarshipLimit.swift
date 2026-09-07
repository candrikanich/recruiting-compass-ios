import Foundation

/// One `scholarship_limits` row (global reference config, seeded from
/// web's data/scholarshipLimits.json — see its README for sourcing/caveats).
struct ScholarshipLimit: Codable, Sendable, Equatable {
  let sport: String
  let division: String
  let total: Double?
  let headCount: Int?
  let equivalency: Double?
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case sport, division, total, notes
    case headCount = "head_count"
    case equivalency
  }
}

/// Exact (sport, division) match only — no wildcard-sport fallback (mirrors
/// web's utils/scholarshipLimits.ts selectScholarshipLimit).
func selectScholarshipLimit(
  _ rows: [ScholarshipLimit],
  sport: String?,
  division: String?
) -> ScholarshipLimit? {
  guard let sport, let division else { return nil }
  let normalizedSport = sport.lowercased()
  return rows.first { $0.sport.lowercased() == normalizedSport && $0.division == division }
}

/// "Athletic Scholarships: 11.7 equivalency (D1 Baseball)" — mirrors web's
/// utils/scholarshipLimits.ts formatScholarshipLine.
func formatScholarshipLine(_ limit: ScholarshipLimit, sport: String, division: String) -> String {
  let detail = "(\(division) \(sport.prefix(1).uppercased() + sport.dropFirst()))"
  if let equivalency = limit.equivalency {
    return "Athletic Scholarships: \(formatNumber(equivalency)) equivalency \(detail)"
  }
  if let headCount = limit.headCount {
    return "Athletic Scholarships: \(headCount) head-count \(detail)"
  }
  if let total = limit.total {
    return "Athletic Scholarships: \(formatNumber(total)) total \(detail)"
  }
  return "Athletic Scholarships: see \(detail)"
}

private func formatNumber(_ value: Double) -> String {
  value.truncatingRemainder(dividingBy: 1) == 0
    ? String(Int(value))
    : String(value)
}
