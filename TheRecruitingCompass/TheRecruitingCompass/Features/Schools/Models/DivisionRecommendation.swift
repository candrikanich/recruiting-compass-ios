import Foundation

/// Division recommendation based on fit score
struct DivisionRecommendation: Sendable {
  let shouldConsiderOtherDivisions: Bool
  let recommendedDivisions: [String]
  let message: String
}
