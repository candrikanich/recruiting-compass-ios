import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FitScoreService")

protocol FitScoreManaging: Sendable {
  func getDivisionRecommendations(division: String?, fitScore: Double?) -> DivisionRecommendation
}

/// Sendable: Stateless service with no mutable properties.
/// Fit scores themselves are computed by the web app and stored on the
/// school row (fit_score); this service only derives recommendations.
final class FitScoreService: FitScoreManaging, Sendable {

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
        message: String(localized: "Based on your fit score, you may want to consider schools in \(recommendations.joined(separator: ", ")).")
      )
    }

    return DivisionRecommendation(
      shouldConsiderOtherDivisions: false,
      recommendedDivisions: [],
      message: ""
    )
  }

  // MARK: - Private Helpers

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
