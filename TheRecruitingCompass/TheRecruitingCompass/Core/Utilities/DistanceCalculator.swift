import Foundation
import CoreLocation

enum DistanceCalculator {
  static func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
    let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)

    let distanceInMeters = fromLocation.distance(from: toLocation)
    let distanceInMiles = distanceInMeters / 1609.34

    return distanceInMiles
  }
}
