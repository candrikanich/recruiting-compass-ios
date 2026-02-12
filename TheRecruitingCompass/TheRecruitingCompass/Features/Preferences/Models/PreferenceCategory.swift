import Foundation

/// Categories for user preferences stored in the database
enum PreferenceCategory: String, Codable, CaseIterable {
  case player = "player"
  case school = "school"
  case notifications = "notifications"
  case dashboard = "dashboard"
  case location = "location"
}
