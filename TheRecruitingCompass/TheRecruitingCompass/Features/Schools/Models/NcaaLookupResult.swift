import Foundation

/// Result of NCAA division/conference lookup
struct NcaaLookupResult: Sendable {
  let division: Division
  let conference: String
  let logo: String?

  nonisolated init(division: Division, conference: String, logo: String? = nil) {
    self.division = division
    self.conference = conference
    self.logo = logo
  }
}
