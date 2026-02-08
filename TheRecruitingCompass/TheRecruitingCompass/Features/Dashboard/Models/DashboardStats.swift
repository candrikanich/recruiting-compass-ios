import Foundation

struct DashboardStats: Codable, Sendable {
  let coachCount: Int
  let schoolCount: Int
  let interactionCount: Int
  let totalOffers: Int
  let acceptedOffers: Int
  let aTierSchoolCount: Int
  let acceptanceRate: Double?

  var acceptanceRateFormatted: String {
    guard let rate = acceptanceRate else { return "N/A" }
    return String(format: "%.0f%%", rate * 100)
  }
}
