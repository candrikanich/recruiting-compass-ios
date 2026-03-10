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
    } else if let nsNumber = any as? NSNumber,
              CFGetTypeID(nsNumber) == CFBooleanGetTypeID() {
      // Distinguish CFBoolean (JSON true/false) from numeric NSNumber (1/0/42...).
      // Without this, NSNumber(intValue: 1) as? Bool succeeds in Swift ObjC bridging,
      // causing integer fields like weight_lbs to be stored as boolean true.
      return .bool(nsNumber.boolValue)
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

/// Sendable: Stateless service with no mutable properties
final class PreferenceServiceImpl: PreferenceManaging, Sendable {
  private let supabaseManager: SupabaseManager
  private static let isoFormatter = ISO8601DateFormatter()

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchPreferences<T: Codable>(category: PreferenceCategory) async throws -> T? {
    logger.debug("Fetching preferences for category: \(category.rawValue)")

    do {
      let userId = try await getCurrentUserId()

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

      // Re-encode JSONValue → Data directly (avoids anyValue → JSONSerialization NSNumber bridging issues).
      let jsonData = try JSONEncoder().encode(response.data)

      do {
        let decoded: T = try JSONDecoder().decode(T.self, from: jsonData)
        logger.info("Successfully fetched preferences for category: \(category.rawValue)")
        return decoded
      } catch let decodeError as DecodingError {
        // One-time migration: repair a Bool/Int type mismatch caused by pre-fix saves
        // where NSNumber(intValue: 1) was wrongly stored as JSONValue.bool(true).
        if let repairedData = repairBoolIntMismatch(in: jsonData, error: decodeError),
           let decoded = try? JSONDecoder().decode(T.self, from: repairedData) {
          logger.warning("[\(category.rawValue)] Repaired Bool/Int type mismatch — re-saving corrected data")
          _ = try? await savePreferences(category: category, data: decoded)
          return decoded
        }
        throw decodeError
      }
    } catch {
      logger.error("Failed to fetch preferences for \(category.rawValue): \(error.localizedDescription)")
      throw PreferenceError.fetchFailed(error.localizedDescription)
    }
  }

  /// Repairs a single-key Bool/Int type mismatch in stored JSON (one-time migration helper).
  private func repairBoolIntMismatch(in data: Data, error: DecodingError) -> Data? {
    guard case .typeMismatch(_, let context) = error,
          let key = context.codingPath.last?.stringValue,
          var dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
      return nil
    }
    let value = dict[key]
    let desc = context.debugDescription
    if let bool = value as? Bool, desc.contains("Int") {
      dict[key] = bool ? 1 : 0
    } else if let int = value as? Int, desc.contains("Bool") {
      dict[key] = int != 0
    } else {
      return nil
    }
    return try? JSONSerialization.data(withJSONObject: dict)
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
          updated_at: Self.isoFormatter.string(from: Date())
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
