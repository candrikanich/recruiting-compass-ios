import Foundation

enum KeychainError: LocalizedError {
  case itemNotFound
  case invalidData
  case saveFailed(OSStatus)
  case deleteFailed(OSStatus)
  case unknown(Error)

  var errorDescription: String? {
    switch self {
    case .itemNotFound: return "Keychain item not found."
    case .invalidData: return "Keychain data is corrupted or unreadable."
    case .saveFailed(let status): return "Keychain save failed (OSStatus \(status))."
    case .deleteFailed(let status): return "Keychain delete failed (OSStatus \(status))."
    case .unknown(let error): return "Keychain error: \(error.localizedDescription)"
    }
  }
}
