import Foundation
@testable import TheRecruitingCompass

final class MockPreferenceManager: PreferenceManaging, @unchecked Sendable {
  var fetchPreferencesResult: Result<Any?, Error> = .success(nil)
  var savePreferencesResult: Result<Any, Error>?
  var deletePreferencesCalled = false

  var fetchPreferencesCalls: [(category: PreferenceCategory, userId: String?)] = []
  var savePreferencesCalls: [(category: PreferenceCategory, userId: String?, data: Any)] = []
  var deletePreferencesCalls: [PreferenceCategory] = []

  func fetchPreferences<T: Codable>(category: PreferenceCategory, userId: String?) async throws -> T? {
    fetchPreferencesCalls.append((category: category, userId: userId))

    switch fetchPreferencesResult {
    case .success(let value):
      return value as? T
    case .failure(let error):
      throw error
    }
  }

  func savePreferences<T: Codable>(category: PreferenceCategory, userId: String?, data: T) async throws -> T {
    savePreferencesCalls.append((category: category, userId: userId, data: data))

    if let result = savePreferencesResult {
      switch result {
      case .success(let value):
        return (value as? T) ?? data
      case .failure(let error):
        throw error
      }
    }

    return data
  }

  func deletePreferences(category: PreferenceCategory) async throws {
    deletePreferencesCalled = true
    deletePreferencesCalls.append(category)
  }

  func reset() {
    fetchPreferencesResult = .success(nil)
    savePreferencesResult = nil
    deletePreferencesCalled = false
    fetchPreferencesCalls.removeAll()
    savePreferencesCalls.removeAll()
    deletePreferencesCalls.removeAll()
  }
}
