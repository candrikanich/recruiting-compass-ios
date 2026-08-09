import Foundation

struct HomeLocation: Codable, Equatable, Sendable {
  var address: String?
  var city: String?
  var state: String?
  var zip: String?
  var latitude: Double?
  var longitude: Double?

  /// Home location counts as "set" for profile completeness when a zip is present
  /// or a geocoded coordinate pair exists. Canonical rule shared with web.
  var isSet: Bool {
    !(zip ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || (latitude != nil && longitude != nil)
  }

  static var `default`: HomeLocation {
    HomeLocation(
      address: nil,
      city: nil,
      state: nil,
      zip: nil,
      latitude: nil,
      longitude: nil
    )
  }

  enum CodingKeys: String, CodingKey {
    case address
    case city
    case state
    case zip
    case latitude
    case longitude
  }
}
