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

/// Simple in-memory cache with TTL and max entry cap. Thread-safe via lock; safe to use from any context.
/// Note: `get` decodes from stored data on each call; hot keys may benefit from a higher-level object cache.
final class InMemoryCache: CacheManaging, @unchecked Sendable {
  private struct Entry: Sendable {
    let data: Data
    let expiresAt: Date
  }

  private var storage: [String: Entry] = [:]
  private var orderedKeys: [String] = []
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private let lock = NSLock()

  /// Max number of entries; oldest (first inserted) is evicted when full.
  private let maxEntries: Int

  static let shared = InMemoryCache()

  init(maxEntries: Int = 200) {
    self.maxEntries = max(1, maxEntries)
  }

  func get<T: Decodable>(_ type: T.Type, forKey key: String) async -> T? {
    lock.lock()
    defer { lock.unlock() }
    guard let entry = storage[key], entry.expiresAt > Date() else {
      return nil
    }
    return try? decoder.decode(T.self, from: entry.data)
  }

  func set<T: Encodable>(_ value: T, forKey key: String, ttlSeconds: TimeInterval) async {
    guard let data = try? encoder.encode(value) else { return }
    let expiresAt = Date().addingTimeInterval(ttlSeconds)
    lock.lock()
    if let idx = orderedKeys.firstIndex(of: key) {
      orderedKeys.remove(at: idx)
    }
    while orderedKeys.count >= maxEntries, let first = orderedKeys.first {
      storage.removeValue(forKey: first)
      orderedKeys.removeFirst()
    }
    storage[key] = Entry(data: data, expiresAt: expiresAt)
    orderedKeys.append(key)
    lock.unlock()
  }

  func remove(forKey key: String) async {
    lock.lock()
    storage.removeValue(forKey: key)
    orderedKeys.removeAll { $0 == key }
    lock.unlock()
  }

  func removeAll() async {
    lock.lock()
    storage.removeAll()
    orderedKeys.removeAll()
    lock.unlock()
  }
}
