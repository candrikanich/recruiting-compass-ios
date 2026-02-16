import Foundation

struct AnalyticsSummary: Codable, Equatable, Sendable {
  let totalSchools: Int
  let totalInteractions: Int
  let totalOffers: Int
  let commitments: Int
  let trends: TrendData?

  struct TrendData: Codable, Equatable, Sendable {
    let schools: Double
    let interactions: Double
    let offers: Double

    var schoolsTrendLabel: String {
      formatTrend(schools)
    }

    var interactionsTrendLabel: String {
      formatTrend(interactions)
    }

    var offersTrendLabel: String {
      formatTrend(offers)
    }

    private func formatTrend(_ value: Double) -> String {
      let sign = value >= 0 ? "+" : ""
      return "\(sign)\(Int(value))% vs last period"
    }
  }

  enum CodingKeys: String, CodingKey {
    case totalSchools = "total_schools"
    case totalInteractions = "total_interactions"
    case totalOffers = "total_offers"
    case commitments
    case trends
  }

  static let empty = AnalyticsSummary(
    totalSchools: 0,
    totalInteractions: 0,
    totalOffers: 0,
    commitments: 0,
    trends: nil
  )
}
