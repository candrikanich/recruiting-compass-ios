import Foundation
import CoreLocation

enum DistanceCalculator {
  /// Earth's radius in miles — matches web `utils/distance.ts`.
  private static let earthRadiusMiles = 3958.8

  /// Great-circle distance in miles (unrounded). Haversine, matching the web app.
  static func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let lat1 = from.latitude * .pi / 180
    let lat2 = to.latitude * .pi / 180
    let deltaLat = (to.latitude - from.latitude) * .pi / 180
    let deltaLon = (to.longitude - from.longitude) * .pi / 180

    // swiftlint:disable:next identifier_name — standard haversine formula variable
    let a = sin(deltaLat / 2) * sin(deltaLat / 2)
      + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
    // swiftlint:disable:next identifier_name — standard haversine formula variable
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return earthRadiusMiles * c
  }

  /// Distance in whole miles, rounded to nearest — matches web `Math.round`.
  static func milesRounded(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Int {
    Int(haversineDistance(from: from, to: to).rounded())
  }

  /// Localized "N miles" with thousands separator — matches web `formatDistance`.
  static func formatMiles(_ miles: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    let number = formatter.string(from: NSNumber(value: miles)) ?? "\(miles)"
    return String(localized: "\(number) miles")
  }
}
