import Foundation
@testable import TheRecruitingCompass

final class MockFitScoreService: FitScoreManaging, @unchecked Sendable {
  var stubbedRecommendation: DivisionRecommendation?

  func getDivisionRecommendations(division: String?, fitScore: Double?) -> DivisionRecommendation {
    return stubbedRecommendation ?? DivisionRecommendation(
      shouldConsiderOtherDivisions: false,
      recommendedDivisions: [],
      message: ""
    )
  }
}
