import Foundation

/// Breakdown of fit score by dimension
struct FitScoreBreakdown: Codable, Sendable {
  let athleticFit: Double?
  let academicFit: Double?
  let opportunityFit: Double?
  let personalFit: Double?
}
