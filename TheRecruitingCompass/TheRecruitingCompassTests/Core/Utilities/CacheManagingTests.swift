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
}
