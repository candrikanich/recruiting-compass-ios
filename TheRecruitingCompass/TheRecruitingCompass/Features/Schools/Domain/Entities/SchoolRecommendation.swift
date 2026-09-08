import Foundation

struct SchoolRecommendation: Codable, Identifiable, Sendable {
  let catalogKey: String
  let name: String
  let division: String?
  let conference: String?
  let state: String?
  let website: String?
  let athleticsUrl: String?
  let score: Double
  let reasons: [String]

  var id: String { catalogKey }

  init(
    catalogKey: String,
    name: String,
    division: String? = nil,
    conference: String? = nil,
    state: String? = nil,
    website: String? = nil,
    athleticsUrl: String? = nil,
    score: Double,
    reasons: [String]
  ) {
    self.catalogKey = catalogKey
    self.name = name
    self.division = division
    self.conference = conference
    self.state = state
    self.website = website
    self.athleticsUrl = athleticsUrl
    self.score = score
    self.reasons = reasons
  }
}
