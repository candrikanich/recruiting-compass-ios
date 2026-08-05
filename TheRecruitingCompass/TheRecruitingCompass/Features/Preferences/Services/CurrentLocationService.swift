import CoreLocation
import Foundation

protocol CurrentLocationProviding: Sendable {
  func requestCurrentLocation() async throws -> CLLocation
}

final class CoreLocationService: CurrentLocationProviding {
  func requestCurrentLocation() async throws -> CLLocation {
    let status = CLLocationManager().authorizationStatus

    switch status {
    case .denied:
      throw LocationError.permissionDenied
    case .restricted:
      throw LocationError.permissionRestricted
    default:
      break
    }

    for try await update in CLLocationUpdate.liveUpdates(.fitness) {
      guard !update.stationary || update.location != nil else { continue }
      if let location = update.location {
        return location
      }
    }

    throw LocationError.locationUnavailable
  }
}
