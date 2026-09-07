import Foundation

/// Read-only NCAA scholarship-limit reference config, keyed by (sport, division).
/// Mirrors web's `scholarship_limits` table / `utils/scholarshipLimits.ts`.
struct ScholarshipLimit: Codable, Sendable {
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
