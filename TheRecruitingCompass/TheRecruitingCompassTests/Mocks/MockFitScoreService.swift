import Foundation
@testable import TheRecruitingCompass

final class MockFitScoreService: FitScoreManaging, @unchecked Sendable {
  var stubbedFitScore: FitScoreResult?
  var stubbedRecommendation: DivisionRecommendation?
  var shouldThrowError = false

  func calculateFitScore(schoolId: String) async throws -> FitScoreResult {
    if shouldThrowError {
      throw NSError(domain: "MockFitScoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
    }
    return stubbedFitScore ?? FitScoreResult(
      score: 75.0,
      tier: .match,
      breakdown: FitScoreBreakdown(
        athleticFit: 80,
        academicFit: 75,
        opportunityFit: 70,
        personalFit: 77
      ),
      missingDimensions: []
    )
  }

  func getDivisionRecommendations(division: String?, fitScore: Double?) -> DivisionRecommendation {
    return stubbedRecommendation ?? DivisionRecommendation(
      shouldConsiderOtherDivisions: false,
      recommendedDivisions: [],
      message: ""
    )
  }
}
