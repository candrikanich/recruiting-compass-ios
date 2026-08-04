import Foundation

struct SchoolPreferences: Codable, Equatable, Sendable {
  var preferences: [SchoolPreference]
  var templateUsed: String?
  var lastUpdated: String?

  static var `default`: SchoolPreferences {
    SchoolPreferences(
      preferences: [],
      templateUsed: nil,
      lastUpdated: Date.now.ISO8601Format()
    )
  }

  enum CodingKeys: String, CodingKey {
    case preferences
    case templateUsed = "template_used"
    case lastUpdated = "last_updated"
  }
}
