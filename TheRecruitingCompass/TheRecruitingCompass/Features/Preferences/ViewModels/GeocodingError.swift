import Foundation

enum GeocodingError: LocalizedError {
  case noResults

  var errorDescription: String? {
    switch self {
    case .noResults:
      return "Could not find coordinates for this address"
    }
  }
}
