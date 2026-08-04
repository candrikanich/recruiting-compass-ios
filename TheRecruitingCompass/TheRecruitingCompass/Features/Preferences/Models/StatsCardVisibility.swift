import Foundation

struct StatsCardVisibility: Codable, Equatable {
  var coaches: Bool
  var schools: Bool
  var interactions: Bool
  var offers: Bool
  var events: Bool
  var performance: Bool
  var notifications: Bool
  var socialMedia: Bool

  static var `default`: StatsCardVisibility {
    StatsCardVisibility(
      coaches: true,
      schools: true,
      interactions: true,
      offers: true,
      events: true,
      performance: true,
      notifications: true,
      socialMedia: true
    )
  }

  enum CodingKeys: String, CodingKey {
    case coaches
    case schools
    case interactions
    case offers
    case events
    case performance
    case notifications
    case socialMedia
  }

  init(coaches: Bool, schools: Bool, interactions: Bool, offers: Bool,
       events: Bool, performance: Bool, notifications: Bool, socialMedia: Bool) {
    self.coaches = coaches
    self.schools = schools
    self.interactions = interactions
    self.offers = offers
    self.events = events
    self.performance = performance
    self.notifications = notifications
    self.socialMedia = socialMedia
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    coaches = try container.decodeIfPresent(Bool.self, forKey: .coaches) ?? true
    schools = try container.decodeIfPresent(Bool.self, forKey: .schools) ?? true
    interactions = try container.decodeIfPresent(Bool.self, forKey: .interactions) ?? true
    offers = try container.decodeIfPresent(Bool.self, forKey: .offers) ?? true
    events = try container.decodeIfPresent(Bool.self, forKey: .events) ?? true
    performance = try container.decodeIfPresent(Bool.self, forKey: .performance) ?? true
    notifications = try container.decodeIfPresent(Bool.self, forKey: .notifications) ?? true
    socialMedia = try container.decodeIfPresent(Bool.self, forKey: .socialMedia) ?? true
  }
}
