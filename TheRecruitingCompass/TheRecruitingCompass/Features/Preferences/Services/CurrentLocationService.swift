import CoreLocation
import Foundation

protocol CurrentLocationProviding: Sendable {
  func requestCurrentLocation() async throws -> CLLocation
}

enum LocationError: LocalizedError {
  case permissionDenied
  case permissionRestricted
  case locationUnavailable

  var errorDescription: String? {
    switch self {
    case .permissionDenied:
      return "Location access is denied. Enable it in Settings > Privacy > Location Services."
    case .permissionRestricted:
      return "Location access is restricted on this device."
    case .locationUnavailable:
      return "Unable to determine your current location. Please try again."
    }
  }
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
