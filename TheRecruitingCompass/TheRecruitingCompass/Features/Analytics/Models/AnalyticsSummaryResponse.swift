import Foundation

struct AnalyticsSummaryResponse: Codable, Sendable {
  let success: Bool
  let data: AnalyticsSummary
}
