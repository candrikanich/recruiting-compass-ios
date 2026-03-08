import Foundation

/// In-memory cache with TTL. Implementations must be thread-safe.
protocol CacheManaging: Sendable {
  /// Returns cached value if present and not expired.
  func get<T: Decodable>(_ type: T.Type, forKey key: String) async -> T?

  /// Stores value with TTL. Overwrites existing.
  func set<T: Encodable>(_ value: T, forKey key: String, ttlSeconds: TimeInterval) async

  /// Removes entry for key.
  func remove(forKey key: String) async

  /// Removes all entries.
  func removeAll() async
}

/// Simple in-memory cache with TTL and max entry cap. MainActor-isolated for Swift 6 compatibility
/// with MainActor-isolated Codable types (School, Coach, etc.).
@MainActor
final class InMemoryCache: CacheManaging {
  private struct Entry {
    let data: Data
    let expiresAt: Date
  }

  private struct ObjectEntry {
    let value: Any
    let expiresAt: Date
  }

  private var storage: [String: Entry] = [:]
  private var objectCache: [String: ObjectEntry] = [:]
  private var orderedKeys: [String] = []
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  /// Max number of entries; oldest (first inserted) is evicted when full.
  private let maxEntries: Int

  static let shared = InMemoryCache()

  init(maxEntries: Int = 200) {
    self.maxEntries = max(1, maxEntries)
  }

  func get<T: Decodable>(_ type: T.Type, forKey key: String) async -> T? {
    let now = Date.now
    if let obj = objectCache[key], obj.expiresAt > now, let value = obj.value as? T {
      return value
    }
    guard let entry = storage[key], entry.expiresAt > now else {
      return nil
    }
    guard let decoded = try? decoder.decode(T.self, from: entry.data) else { return nil }
    objectCache[key] = ObjectEntry(value: decoded, expiresAt: entry.expiresAt)
    return decoded
  }

  func set<T: Encodable>(_ value: T, forKey key: String, ttlSeconds: TimeInterval) async {
    guard let data = try? encoder.encode(value) else { return }
    let expiresAt = Date.now.addingTimeInterval(ttlSeconds)
    if let idx = orderedKeys.firstIndex(of: key) {
      orderedKeys.remove(at: idx)
    }
    while orderedKeys.count >= maxEntries, let first = orderedKeys.first {
      storage.removeValue(forKey: first)
      objectCache.removeValue(forKey: first)
      orderedKeys.removeFirst()
    }
    storage[key] = Entry(data: data, expiresAt: expiresAt)
    objectCache[key] = ObjectEntry(value: value, expiresAt: expiresAt)
    orderedKeys.append(key)
  }

  func remove(forKey key: String) async {
    storage.removeValue(forKey: key)
    objectCache.removeValue(forKey: key)
    orderedKeys.removeAll { $0 == key }
  }

  func removeAll() async {
    storage.removeAll()
    objectCache.removeAll()
    orderedKeys.removeAll()
  }
}
