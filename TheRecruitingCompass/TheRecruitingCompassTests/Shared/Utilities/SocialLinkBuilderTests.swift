import XCTest
@testable import TheRecruitingCompass

final class SocialLinkBuilderTests: XCTestCase {
    nonisolated deinit {}

    func testTwitterStripsAtAndBuildsURL() {
        XCTAssertEqual(SocialLinkBuilder.twitterURL("@player")?.absoluteString,
                       "https://twitter.com/player")
        XCTAssertEqual(SocialLinkBuilder.twitterURL("player")?.absoluteString,
                       "https://twitter.com/player")
    }

    func testInstagramBuildsURL() {
        XCTAssertEqual(SocialLinkBuilder.instagramURL("@player")?.absoluteString,
                       "https://instagram.com/player")
    }

    func testTiktokPrefixesAt() {
        XCTAssertEqual(SocialLinkBuilder.tiktokURL("player")?.absoluteString,
                       "https://tiktok.com/@player")
    }

    func testFacebookNormalizesScheme() {
        XCTAssertEqual(SocialLinkBuilder.facebookURL("facebook.com/player")?.absoluteString,
                       "https://facebook.com/player")
        XCTAssertEqual(SocialLinkBuilder.facebookURL("https://facebook.com/player")?.absoluteString,
                       "https://facebook.com/player")
    }

    func testBlankOrNilReturnsNil() {
        XCTAssertNil(SocialLinkBuilder.twitterURL(nil))
        XCTAssertNil(SocialLinkBuilder.twitterURL("  "))
        XCTAssertNil(SocialLinkBuilder.facebookURL(""))
    }
}
