import Foundation
@testable import TheRecruitingCompass

final class MockPreferenceManager: PreferenceManaging {
  var fetchPreferencesResult: Result<Any?, Error> = .success(nil)
  var savePreferencesResult: Result<Any, Error>?
  var deletePreferencesCalled = false

  var fetchPreferencesCalls: [PreferenceCategory] = []
  var savePreferencesCalls: [(category: PreferenceCategory, data: Any)] = []
  var deletePreferencesCalls: [PreferenceCategory] = []

  func fetchPreferences<T: Codable>(category: PreferenceCategory) async throws -> T? {
    fetchPreferencesCalls.append(category)

    switch fetchPreferencesResult {
    case .success(let value):
      return value as? T
    case .failure(let error):
      throw error
    }
  }

  func savePreferences<T: Codable>(category: PreferenceCategory, data: T) async throws -> T {
    savePreferencesCalls.append((category: category, data: data))

    if let result = savePreferencesResult {
      switch result {
      case .success(let value):
        return value as! T
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
