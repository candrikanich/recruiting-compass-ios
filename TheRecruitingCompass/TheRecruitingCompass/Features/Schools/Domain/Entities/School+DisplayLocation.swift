import Foundation

extension School {
  /// "City, ST" for list tiles. Prefers the free-text `location`, then the school's own city/state, then the
  /// College Scorecard city/state in `academicInfo` — most schools only carry it there, not in `location`.
  var displayLocation: String? {
    if let location = Self.nonEmpty(location) {
      return location
    }
    let city = Self.nonEmpty(city) ?? Self.nonEmpty(academicInfo?.city)
    let state = Self.nonEmpty(state) ?? Self.nonEmpty(academicInfo?.state)
    let parts = [city, state].compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: ", ")
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
      return nil
    }
    return trimmed
  }
}
