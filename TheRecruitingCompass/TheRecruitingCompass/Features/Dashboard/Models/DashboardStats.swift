import Foundation

struct DashboardStats: Codable, Sendable {
  let coachCount: Int
  let schoolCount: Int
  let interactionCount: Int
  let totalOffers: Int
  let acceptedOffers: Int
  let acceptanceRate: Double?
  /// Distinct schools with at least one offer — NOT the raw offer-row count.
  let schoolsWithOffers: Int
  /// Interactions logged in the current calendar month (UTC), not all-time.
  let interactionsThisMonth: Int

  init(
    coachCount: Int,
    schoolCount: Int,
    interactionCount: Int,
    totalOffers: Int,
    acceptedOffers: Int,
    acceptanceRate: Double?,
    schoolsWithOffers: Int = 0,
    interactionsThisMonth: Int = 0
  ) {
    self.coachCount = coachCount
    self.schoolCount = schoolCount
    self.interactionCount = interactionCount
    self.totalOffers = totalOffers
    self.acceptedOffers = acceptedOffers
    self.acceptanceRate = acceptanceRate
    self.schoolsWithOffers = schoolsWithOffers
    self.interactionsThisMonth = interactionsThisMonth
  }

  var acceptanceRateFormatted: String {
    guard let rate = acceptanceRate else { return "N/A" }
    return rate.formatted(.percent.precision(.fractionLength(0)))
  }
}
