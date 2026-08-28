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
}
