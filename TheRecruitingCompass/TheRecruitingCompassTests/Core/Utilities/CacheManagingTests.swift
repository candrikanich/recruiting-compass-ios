import XCTest
@testable import TheRecruitingCompass

@MainActor
final class CacheManagingTests: XCTestCase {
  nonisolated deinit {}

  func testGetOrFetch_MissStoresValue_HitSkipsFetch() async throws {
    let cache = InMemoryCache()
    var fetches = 0

    let miss = try await cache.getOrFetch([String].self, forKey: "k", ttlSeconds: 60) {
      fetches += 1
      return ["a"]
    }
    XCTAssertFalse(miss.cacheHit)
    XCTAssertEqual(miss.value, ["a"])
    XCTAssertEqual(fetches, 1)

    let hit = try await cache.getOrFetch([String].self, forKey: "k", ttlSeconds: 60) {
      fetches += 1
      return ["b"]
    }
    XCTAssertTrue(hit.cacheHit)
    XCTAssertEqual(hit.value, ["a"])
    XCTAssertEqual(fetches, 1)
  }

  func testGetOrFetch_DoesNotStoreWhenFetchThrows() async {
    struct Boom: Error {}
    let cache = InMemoryCache()

    do {
      _ = try await cache.getOrFetch([String].self, forKey: "k", ttlSeconds: 60) {
        throw Boom()
      }
      XCTFail("Expected throw")
    } catch is Boom {
      // expected
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    let cached = await cache.get([String].self, forKey: "k")
    XCTAssertNil(cached)
  }

  func testStaleWhileRevalidate_MissFetchesAndStores() async throws {
    let cache = InMemoryCache()
    var staleCalls = 0
    var fetches = 0

    let fresh = try await cache.staleWhileRevalidate(
      [String].self,
      forKey: "k",
      ttlSeconds: 60,
      onStale: { _ in staleCalls += 1 },
      fetch: {
        fetches += 1
        return ["a"]
      }
    )

    XCTAssertEqual(fresh, ["a"])
    XCTAssertEqual(fetches, 1)
    XCTAssertEqual(staleCalls, 0)
    let stored = await cache.get([String].self, forKey: "k")
    XCTAssertEqual(stored, ["a"])
  }

  func testStaleWhileRevalidate_HitPaintsStaleThenStoresFresh() async throws {
    let cache = InMemoryCache()
    await cache.set(["old"], forKey: "k", ttlSeconds: 60)

    var painted: [String]?
    var fetches = 0

    let fresh = try await cache.staleWhileRevalidate(
      [String].self,
      forKey: "k",
      ttlSeconds: 60,
      onStale: { painted = $0 },
      fetch: {
        fetches += 1
        return ["new"]
      }
    )

    XCTAssertEqual(painted, ["old"])
    XCTAssertEqual(fresh, ["new"])
    XCTAssertEqual(fetches, 1)
    let stored = await cache.get([String].self, forKey: "k")
    XCTAssertEqual(stored, ["new"])
  }

  func testStaleWhileRevalidate_FetchThrowKeepsExistingEntry() async {
    struct Boom: Error {}
    let cache = InMemoryCache()
    await cache.set(["old"], forKey: "k", ttlSeconds: 60)

    var painted: [String]?
    do {
      _ = try await cache.staleWhileRevalidate(
        [String].self,
        forKey: "k",
        ttlSeconds: 60,
        onStale: { painted = $0 },
        fetch: { throw Boom() }
      )
      XCTFail("Expected throw")
    } catch is Boom {
      XCTAssertEqual(painted, ["old"])
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    let stored = await cache.get([String].self, forKey: "k")
    XCTAssertEqual(stored, ["old"])
  }

  func testGet_ReturnsStoredValueWithoutJSONRoundTrip() async {
    let cache = InMemoryCache()
    await cache.set(["a", "b"], forKey: "k", ttlSeconds: 60)

    let first = await cache.get([String].self, forKey: "k")
    let second = await cache.get([String].self, forKey: "k")

    XCTAssertEqual(first, ["a", "b"])
    XCTAssertEqual(second, ["a", "b"])
  }

  func testGet_ExpiredEntryIsEvicted() async {
    let cache = InMemoryCache()
    await cache.set(["stale"], forKey: "k", ttlSeconds: -1)

    let expired = await cache.get([String].self, forKey: "k")
    XCTAssertNil(expired)
    // Re-set should not FIFO-evict a zombie expired key.
    await cache.set(["fresh"], forKey: "other", ttlSeconds: 60)
    let fresh = await cache.get([String].self, forKey: "other")
    XCTAssertEqual(fresh, ["fresh"])
  }

  func testGet_TypeMismatchReturnsNil() async {
    let cache = InMemoryCache()
    await cache.set(["a"], forKey: "k", ttlSeconds: 60)

    let wrongType = await cache.get(Int.self, forKey: "k")
    XCTAssertNil(wrongType)
    let stored = await cache.get([String].self, forKey: "k")
    XCTAssertEqual(stored, ["a"])
  }

  func testSet_EvictsOldestWhenAtCapacity() async {
    let cache = InMemoryCache(maxEntries: 2)
    await cache.set(1, forKey: "a", ttlSeconds: 60)
    await cache.set(2, forKey: "b", ttlSeconds: 60)
    await cache.set(3, forKey: "c", ttlSeconds: 60)

    let evicted = await cache.get(Int.self, forKey: "a")
    let keptB = await cache.get(Int.self, forKey: "b")
    let keptC = await cache.get(Int.self, forKey: "c")
    XCTAssertNil(evicted)
    XCTAssertEqual(keptB, 2)
    XCTAssertEqual(keptC, 3)
  }

  func testSet_OverwriteDoesNotEvictOtherKeys() async {
    let cache = InMemoryCache(maxEntries: 2)
    await cache.set(1, forKey: "a", ttlSeconds: 60)
    await cache.set(2, forKey: "b", ttlSeconds: 60)
    await cache.set(10, forKey: "a", ttlSeconds: 60)

    let a = await cache.get(Int.self, forKey: "a")
    let b = await cache.get(Int.self, forKey: "b")
    XCTAssertEqual(a, 10)
    XCTAssertEqual(b, 2)
  }

  func testSet_PrefersEvictingExpiredBeforeLiveEntries() async {
    let cache = InMemoryCache(maxEntries: 2)
    await cache.set(["live"], forKey: "keep", ttlSeconds: 60)
    await cache.set(["dead"], forKey: "expired", ttlSeconds: -1)
    await cache.set(["new"], forKey: "added", ttlSeconds: 60)

    let expired = await cache.get([String].self, forKey: "expired")
    let keep = await cache.get([String].self, forKey: "keep")
    let added = await cache.get([String].self, forKey: "added")
    XCTAssertNil(expired)
    XCTAssertEqual(keep, ["live"])
    XCTAssertEqual(added, ["new"])
  }
}
