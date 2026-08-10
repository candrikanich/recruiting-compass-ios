import XCTest
@testable import TheRecruitingCompass

final class PublicProfileDataTests: XCTestCase {
    nonisolated deinit {}

    func testConstructsWithAllSectionsNil() {
        let data = PublicProfileData(
            playerName: "Jordan Rivera", photoUrl: nil,
            headerColor: .slate, bio: nil,
            academics: nil, athletic: nil, film: nil, schools: nil
        )
        XCTAssertEqual(data.playerName, "Jordan Rivera")
        XCTAssertNil(data.athletic)
    }

    func testEquatableAcrossNestedSections() {
        let a = PublicProfileData.FilmItem(title: "Senior Highlights", url: "https://x/y")
        let b = PublicProfileData.FilmItem(title: "Senior Highlights", url: "https://x/y")
        XCTAssertEqual(a, b)
    }
}
