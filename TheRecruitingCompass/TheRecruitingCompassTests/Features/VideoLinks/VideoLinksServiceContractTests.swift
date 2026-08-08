import XCTest
@testable import TheRecruitingCompass

final class VideoLinksServiceContractTests: XCTestCase {
  func test_mockCreateAppendsAndFetchReturns() async throws {
    let mock = MockVideoLinksService()
    let req = VideoLinkCreateRequest(userId: "u1", familyUnitId: "f1",
                                     platform: .hudl, url: "https://hudl.com/x",
                                     title: "Reel", position: 0)
    let created = try await mock.createVideoLink(req)
    XCTAssertEqual(created.userId, "u1")
    XCTAssertEqual(created.platform, .hudl)
    let all = try await mock.fetchVideoLinks(userId: "u1")
    XCTAssertEqual(all.count, 1)
    XCTAssertEqual(all.first?.url, "https://hudl.com/x")
  }

  func test_mockDeleteRemoves() async throws {
    let mock = MockVideoLinksService()
    let created = try await mock.createVideoLink(
      .init(userId: "u1", familyUnitId: nil, platform: .vimeo,
            url: "https://v", title: nil, position: 0))
    try await mock.deleteVideoLink(id: created.id, userId: "u1")
    let all = try await mock.fetchVideoLinks(userId: "u1")
    XCTAssertTrue(all.isEmpty)
  }
}
