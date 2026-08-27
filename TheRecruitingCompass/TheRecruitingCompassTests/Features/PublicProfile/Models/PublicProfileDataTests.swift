import XCTest
@testable import TheRecruitingCompass

final class PublicProfileDataTests: XCTestCase {
    nonisolated deinit {}

    func testConstructsWithAllSectionsNil() {
        let data = PublicProfileData(
            playerName: "Jordan Rivera", photoUrl: nil,
            headerColor: .slate, bio: nil,
            academics: nil, credentials: nil, metrics: nil, film: nil,
            lookingFor: nil, valuesTags: [], teamHistory: nil, awards: nil,
            social: nil, commitmentStatus: .uncommitted, committedSchoolName: nil,
            updatedAt: nil, visibleSectionOrder: []
        )
        XCTAssertEqual(data.playerName, "Jordan Rivera")
        XCTAssertNil(data.credentials)
        XCTAssertNil(data.metrics)
        XCTAssertTrue(data.valuesTags.isEmpty)
    }

    func testSocialSectionIsEmptyWhenAllHandlesBlank() {
        let empty = PublicProfileData.SocialSection(
            twitterHandle: "  ", instagramHandle: "", tiktokHandle: nil, facebookUrl: nil)
        XCTAssertTrue(empty.isEmpty)

        let filled = PublicProfileData.SocialSection(
            twitterHandle: "@player", instagramHandle: nil, tiktokHandle: nil, facebookUrl: nil)
        XCTAssertFalse(filled.isEmpty)
    }

    func testEquatableAcrossNestedSections() {
        let a = PublicProfileData.FilmItem(title: "Senior Highlights", url: "https://x/y")
        let b = PublicProfileData.FilmItem(title: "Senior Highlights", url: "https://x/y")
        XCTAssertEqual(a, b)
    }

    func testMetricEntryIdentifiableByKey() {
        let entry = PublicProfileData.MetricEntry(
            key: "batting_avg", label: "Batting Average", value: ".410", unit: "", verified: true
        )
        XCTAssertEqual(entry.id, "batting_avg")
    }

    func testTeamHistoryEntryContactOnlyWhenPresent() {
        let noContact = PublicProfileData.TeamHistoryEntry(
            name: "Central HS", level: "12th Grade", coach: "Coach Lee", contact: nil, years: nil
        )
        XCTAssertNil(noContact.contact)

        let withContact = PublicProfileData.TeamHistoryEntry(
            name: "Travel Elite", level: "Travel", coach: "Coach Diaz", contact: "555-0100", years: "2024-2025"
        )
        XCTAssertEqual(withContact.contact, "555-0100")
    }
}
