import Foundation

struct HomeLocation: Codable, Equatable {
  var address: String?
  var city: String?
  var state: String?
  var zip: String?
  var latitude: Double?
  var longitude: Double?

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
