import Foundation

enum BiometricError: LocalizedError {
  case notAvailable
  case lockout
  case cancelled
  case failed

  var errorDescription: String? {
    switch self {
    case .notAvailable: return "Biometric authentication is not available on this device"
    case .lockout:      return "Too many failed attempts. Please sign in with your password."
    case .cancelled:    return nil
    case .failed:       return "Biometric authentication failed"
    }
  }
}

extension BiometricError: Equatable {}
