import Foundation

/// Result of fit score calculation
struct FitScoreResult: Codable, Sendable {
  let score: Double
  let tier: FitTier
  let breakdown: FitScoreBreakdown
  let missingDimensions: [String]
}
