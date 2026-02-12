import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "PreferenceService")

/// Response structure from the user_preferences table
private struct PreferenceResponse: Codable {
  let data: JSONValue
  let updatedAt: String?

  enum CodingKeys: String, CodingKey {
    case data
    case updatedAt = "updated_at"
  }
}

/// Payload for updating preferences
private struct PreferenceUpdatePayload: Encodable {
  let data: JSONValue
  let updated_at: String
}

/// Payload for inserting preferences
private struct PreferenceInsertPayload: Encodable {
  let user_id: String
  let category: String
  let data: JSONValue
}

/// Generic JSON value that can be converted to/from Any
private enum JSONValue: Codable, Equatable {
  case null
  case bool(Bool)
  case int(Int)
  case double(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      self = .null
    } else if let bool = try? container.decode(Bool.self) {
      self = .bool(bool)
    } else if let int = try? container.decode(Int.self) {
      self = .int(int)
    } else if let double = try? container.decode(Double.self) {
      self = .double(double)
    } else if let string = try? container.decode(String.self) {
      self = .string(string)
    } else if let array = try? container.decode([JSONValue].self) {
      self = .array(array)
    } else if let object = try? container.decode([String: JSONValue].self) {
      self = .object(object)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Cannot decode JSONValue"
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case .null:
      try container.encodeNil()
    case .bool(let value):
      try container.encode(value)
    case .int(let value):
      try container.encode(value)
    case .double(let value):
      try container.encode(value)
    case .string(let value):
      try container.encode(value)
    case .array(let value):
      try container.encode(value)
    case .object(let value):
      try container.encode(value)
    }
  }

  var anyValue: Any {
    switch self {
    case .null:
      return NSNull()
    case .bool(let value):
      return value
    case .int(let value):
      return value
    case .double(let value):
      return value
    case .string(let value):
      return value
    case .array(let value):
      return value.map { $0.anyValue }
    case .object(let value):
      return value.mapValues { $0.anyValue }
    }
  }

  static func from(_ any: Any) -> JSONValue {
    if any is NSNull {
      return .null
    } else if let bool = any as? Bool {
      return .bool(bool)
    } else if let int = any as? Int {
      return .int(int)
    } else if let double = any as? Double {
      return .double(double)
    } else if let string = any as? String {
      return .string(string)
    } else if let array = any as? [Any] {
      return .array(array.map { JSONValue.from($0) })
    } else if let object = any as? [String: Any] {
      return .object(object.mapValues { JSONValue.from($0) })
    } else {
      return .null
    }
  }
}

final class PreferenceServiceImpl: PreferenceManaging, @unchecked Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchPreferences<T: Codable>(category: PreferenceCategory) async throws -> T? {
    logger.debug("Fetching preferences for category: \(category.rawValue)")

    do {
      let userId = try await getCurrentUserId()

      // Fetch from user_preferences table
      let rows: [PreferenceResponse] = try await supabaseManager.client
        .from("user_preferences")
        .select("data, updated_at")
        .eq("user_id", value: userId)
        .eq("category", value: category.rawValue)
        .execute()
        .value

      guard let response = rows.first else {
        logger.info("No preferences found for category: \(category.rawValue)")
        return nil
      }

      // Convert JSONValue to target type
      let jsonData = try JSONSerialization.data(withJSONObject: response.data.anyValue)
      let decoded = try JSONDecoder().decode(T.self, from: jsonData)

      logger.info("Successfully fetched preferences for category: \(category.rawValue)")
      return decoded
    } catch {
      logger.error("Failed to fetch preferences for \(category.rawValue): \(error.localizedDescription)")
      throw PreferenceError.fetchFailed(error.localizedDescription)
    }
  }

  func savePreferences<T: Codable>(category: PreferenceCategory, data: T) async throws -> T {
    logger.debug("Saving preferences for category: \(category.rawValue)")

    do {
      let userId = try await getCurrentUserId()

      // Encode data to JSON dictionary
      let jsonData = try JSONEncoder().encode(data)
      guard let dictionary = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
        throw PreferenceError.invalidData
      }

      let wrappedData = JSONValue.from(dictionary)

      // Check if preferences already exist
      let existing: [PreferenceResponse] = try await supabaseManager.client
        .from("user_preferences")
        .select("data")
        .eq("user_id", value: userId)
        .eq("category", value: category.rawValue)
        .execute()
        .value

      if !existing.isEmpty {
        // Update existing preferences
        let payload = PreferenceUpdatePayload(
          data: wrappedData,
          updated_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabaseManager.client
          .from("user_preferences")
          .update(payload)
          .eq("user_id", value: userId)
          .eq("category", value: category.rawValue)
          .execute()
      } else {
        // Insert new preferences
        let payload = PreferenceInsertPayload(
          user_id: userId,
          category: category.rawValue,
          data: wrappedData
        )

        try await supabaseManager.client
          .from("user_preferences")
          .insert(payload)
          .execute()
      }

      logger.info("Successfully saved preferences for category: \(category.rawValue)")
      return data
    } catch {
      logger.error("Failed to save preferences for \(category.rawValue): \(error.localizedDescription)")
      throw PreferenceError.saveFailed(error.localizedDescription)
    }
  }

  func deletePreferences(category: PreferenceCategory) async throws {
    logger.debug("Deleting preferences for category: \(category.rawValue)")

    do {
      let userId = try await getCurrentUserId()

      try await supabaseManager.client
        .from("user_preferences")
        .delete()
        .eq("user_id", value: userId)
        .eq("category", value: category.rawValue)
        .execute()

      logger.info("Successfully deleted preferences for category: \(category.rawValue)")
    } catch {
      logger.error("Failed to delete preferences for \(category.rawValue): \(error.localizedDescription)")
      throw PreferenceError.deleteFailed(error.localizedDescription)
    }
  }

  // MARK: - Private Helpers

  private func getCurrentUserId() async throws -> String {
    guard let session = try await supabaseManager.getCurrentSession() else {
      throw PreferenceError.notAuthenticated
    }
    return session.user.id
  }
}

enum PreferenceError: LocalizedError {
  case notAuthenticated
  case invalidData
  case fetchFailed(String)
  case saveFailed(String)
  case deleteFailed(String)

  var errorDescription: String? {
    switch self {
    case .notAuthenticated:
      return "You must be signed in to access preferences"
    case .invalidData:
      return "Invalid preference data format"
    case .fetchFailed(let message):
      return "Failed to load preferences: \(message)"
    case .saveFailed(let message):
      return "Failed to save preferences: \(message)"
    case .deleteFailed(let message):
      return "Failed to delete preferences: \(message)"
    }
  }
}
