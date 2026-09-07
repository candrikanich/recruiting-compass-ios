import XCTest
@testable import TheRecruitingCompass

final class ConferenceUrlsTests: XCTestCase {
  func test_loadsBundledConferenceUrls() {
    // Confirms conferenceUrls.json is actually bundled into the test target
    // and decodes — the real failure mode this guards against is the file
    // being dropped in Resources/ but never added to the Xcode target.
    XCTAssertFalse(ConferenceUrls.map.isEmpty, "conferenceUrls.json failed to load from the bundle")
  }

  func test_resolvesKnownConference() {
    XCTAssertEqual(ConferenceUrls.url(for: "Big Ten")?.absoluteString, "https://bigten.org")
  }

  func test_returnsNilForUnknownOrNilConference() {
    XCTAssertNil(ConferenceUrls.url(for: "Some Made Up Conference"))
    XCTAssertNil(ConferenceUrls.url(for: nil))
  }
}
