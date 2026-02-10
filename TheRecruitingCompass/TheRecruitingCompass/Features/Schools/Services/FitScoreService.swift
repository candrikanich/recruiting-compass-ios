import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FitScoreService")

protocol FitScoreManaging: Sendable {
  func calculateFitScore(schoolId: String) async throws -> FitScoreResult
  func getDivisionRecommendations(division: String?, fitScore: Double?) -> DivisionRecommendation
}

final class FitScoreService: FitScoreManaging, @unchecked Sendable {

  /// Calculate fit score for a school
  /// NOTE: This is a simplified client-side calculation
  /// Can be replaced with API call in the future
  func calculateFitScore(schoolId: String) async throws -> FitScoreResult {
    logger.debug("Calculating fit score for school: \(schoolId)")

    // TODO: Implement actual fit score calculation logic
    // This would typically:
    // 1. Fetch school data
    // 2. Fetch student profile data
    // 3. Calculate scores for each dimension
    // 4. Combine into overall score
    // 5. Determine tier

    // For now, return a placeholder result
    // In production, this would call the actual calculation logic
    // or make an API call to a backend service

    let breakdown = FitScoreBreakdown(
      athleticFit: 75.0,
      academicFit: 80.0,
      opportunityFit: 70.0,
      personalFit: 85.0
    )

    let averageScore = [
      breakdown.athleticFit,
      breakdown.academicFit,
      breakdown.opportunityFit,
      breakdown.personalFit
    ]
    .compactMap { $0 }
    .reduce(0, +) / 4.0

    let tier = determineFitTier(score: averageScore)

    logger.info("Fit score calculated: \(averageScore), tier: \(tier.displayName)")

    return FitScoreResult(
      score: averageScore,
      tier: tier,
      breakdown: breakdown,
      missingDimensions: []
    )
  }

  /// Get division recommendations based on fit score
  func getDivisionRecommendations(division: String?, fitScore: Double?) -> DivisionRecommendation {
    guard let currentDivision = division,
          let score = fitScore else {
      return DivisionRecommendation(
        shouldConsiderOtherDivisions: false,
        recommendedDivisions: [],
        message: ""
      )
    }

    // Logic: If fit score is low for current division, recommend considering others
    let isLowFit = score < 50.0

    if isLowFit {
      let recommendations = getAlternativeDivisions(from: currentDivision)
      return DivisionRecommendation(
        shouldConsiderOtherDivisions: true,
        recommendedDivisions: recommendations,
        message: "Based on your fit score, you may want to consider schools in \(recommendations.joined(separator: ", "))."
      )
    }

    return DivisionRecommendation(
      shouldConsiderOtherDivisions: false,
      recommendedDivisions: [],
      message: ""
    )
  }

  // MARK: - Private Helpers

  private func determineFitTier(score: Double) -> FitTier {
    switch score {
    case 80...:
      return .safety
    case 60..<80:
      return .match
    case 40..<60:
      return .reach
    default:
      return .unlikely
    }
  }

  private func getAlternativeDivisions(from currentDivision: String) -> [String] {
    switch currentDivision.uppercased() {
    case "D1":
      return ["D2", "D3"]
    case "D2":
      return ["D1", "D3"]
    case "D3":
      return ["D2", "NAIA"]
    case "NAIA":
      return ["D2", "D3"]
    default:
      return []
    }
  }
}
