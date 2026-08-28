import Foundation

/// In-memory cache with TTL. Implementations must be thread-safe.
protocol CacheManaging: Sendable {
  /// Returns cached value if present and not expired.
  func get<T: Decodable & Sendable>(_ type: T.Type, forKey key: String) async -> T?

  /// Stores value with TTL. Overwrites existing.
  func set<T: Encodable & Sendable>(_ value: T, forKey key: String, ttlSeconds: TimeInterval) async

  /// Removes entry for key.
  func remove(forKey key: String) async

  /// Removes all entries.
  func removeAll() async
}

extension CacheManaging {
  /// Returns the cached value when present and unexpired; otherwise runs `fetch`,
  /// stores the result with `ttlSeconds`, and returns it.
  func getOrFetch<T: Codable & Sendable>(
    _ type: T.Type,
    forKey key: String,
    ttlSeconds: TimeInterval,
    fetch: () async throws -> T
  ) async throws -> (value: T, cacheHit: Bool) {
    if let cached = await get(type, forKey: key) {
      return (cached, true)
    }
    let fetched = try await fetch()
    await set(fetched, forKey: key, ttlSeconds: ttlSeconds)
    return (fetched, false)
  }

  /// Always fetches. If a cached value exists, `onStale` runs before the
  /// network call so the UI can paint immediately. Fetch failure does not
  /// evict the existing entry.
  func staleWhileRevalidate<T: Codable & Sendable>(
    _ type: T.Type,
    forKey key: String,
    ttlSeconds: TimeInterval,
    onStale: ((T) -> Void)? = nil,
    fetch: () async throws -> T
  ) async throws -> T {
    if let stale = await get(type, forKey: key) {
      onStale?(stale)
    }
    let fresh = try await fetch()
    await set(fresh, forKey: key, ttlSeconds: ttlSeconds)
    return fresh
  }
}

/// In-memory cache with TTL and max entry cap.
///
/// Stores values directly (no JSON round-trip). MainActor-isolated for Swift 6
/// compatibility with MainActor-isolated Codable types (School, Coach, etc.).
@MainActor
final class InMemoryCache: CacheManaging {
  nonisolated deinit {}

  private struct ObjectEntry {
    let value: Any
    let expiresAt: Date
  }

  private var objectCache: [String: ObjectEntry] = [:]
  /// Insertion order for FIFO eviction. Overwrites move the key to the end.
  private var orderedKeys: [String] = []

  /// Max number of entries; oldest (first inserted) is evicted when full.
  private let maxEntries: Int

  static let shared = InMemoryCache()

  init(maxEntries: Int = 200) {
    self.maxEntries = max(1, maxEntries)
  }

  func get<T: Decodable & Sendable>(_ type: T.Type, forKey key: String) async -> T? {
    guard let obj = objectCache[key] else { return nil }
    if obj.expiresAt <= Date.now {
      evict(key)
      return nil
    }
    return obj.value as? T
  }

  func set<T: Encodable & Sendable>(_ value: T, forKey key: String, ttlSeconds: TimeInterval) async {
    let expiresAt = Date.now.addingTimeInterval(ttlSeconds)
    if let idx = orderedKeys.firstIndex(of: key) {
      orderedKeys.remove(at: idx)
    } else {
      evictExpired()
      while orderedKeys.count >= maxEntries {
        evictOldest()
      }
    }
    objectCache[key] = ObjectEntry(value: value, expiresAt: expiresAt)
    orderedKeys.append(key)
  }

  func remove(forKey key: String) async {
    evict(key)
  }

  func removeAll() async {
    objectCache.removeAll(keepingCapacity: false)
    orderedKeys.removeAll(keepingCapacity: false)
  }

  private func evict(_ key: String) {
    objectCache.removeValue(forKey: key)
    if let idx = orderedKeys.firstIndex(of: key) {
      orderedKeys.remove(at: idx)
    }
  }

  private func evictOldest() {
    guard let first = orderedKeys.first else { return }
    objectCache.removeValue(forKey: first)
    orderedKeys.removeFirst()
  }

  private func evictExpired() {
    let now = Date.now
    let expired = orderedKeys.filter { key in
      guard let obj = objectCache[key] else { return true }
      return obj.expiresAt <= now
    }
    for key in expired {
      evict(key)
    }
  }
}
