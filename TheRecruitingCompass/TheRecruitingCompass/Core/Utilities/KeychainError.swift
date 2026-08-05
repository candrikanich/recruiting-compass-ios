import Foundation

enum KeychainError: Error {
  case itemNotFound
  case invalidData
  case saveFailed(OSStatus)
  case deleteFailed(OSStatus)
  case unknown(Error)
}
