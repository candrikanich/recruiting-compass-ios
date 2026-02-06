import Foundation
import Security

enum KeychainError: Error {
  case itemNotFound
  case invalidData
  case saveFailed(OSStatus)
  case deleteFailed(OSStatus)
  case unknown(Error)
}

@MainActor
final class KeychainHelper {
  static let shared = KeychainHelper()

  private let service = "com.chrisandrikanich.TheRecruitingCompass"

  private init() {}

  // MARK: - Generic Save/Load

  func save<T: Encodable>(_ object: T, forKey key: String) throws {
    let data = try JSONEncoder().encode(object)
    try saveData(data, forKey: key)
  }

  func load<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T {
    let data = try loadData(forKey: key)
    return try JSONDecoder().decode(T.self, from: data)
  }

  func delete(forKey key: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key
    ]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.deleteFailed(status)
    }
  }

  // MARK: - Private Helpers

  private func saveData(_ data: Data, forKey key: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecValueData as String: data
    ]

    // Try to delete existing item first
    SecItemDelete(query as CFDictionary)

    // Then add the new item
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw KeychainError.saveFailed(status)
    }
  }

  private func loadData(forKey key: String) throws -> Data {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess else {
      if status == errSecItemNotFound {
        throw KeychainError.itemNotFound
      }
      throw KeychainError.unknown(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
    }

    guard let data = result as? Data else {
      throw KeychainError.invalidData
    }

    return data
  }
}
