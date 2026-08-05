import Foundation

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
