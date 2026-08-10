import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SendProfileViewModelTests: XCTestCase {
    nonisolated deinit {}

    func testShareURLIncludesRefToken() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = PlayerProfile(
            id: "p1", userId: "u1", familyUnitId: "f1", hashSlug: "ab12cd",
            vanitySlug: "jordan", isPublished: true, bio: nil, headerColor: "slate",
            showAcademics: true, showAthletic: true, showFilm: true, showSchools: true,
            createdAt: "", updatedAt: ""
        )
        mock.stubTrackingLink = ProfileTrackingLink(
            id: "t1", profileId: "p1", coachId: "c1", refToken: "abcd1234",
            viewCount: 0, lastViewedAt: nil, createdAt: ""
        )
        let vm = SendProfileViewModel(service: mock, authManager: MockAuthManager())
        let url = await vm.shareURL(forCoachId: "c1")
        XCTAssertEqual(url?.absoluteString.contains("/p/jordan"), true)
        XCTAssertEqual(url?.absoluteString.contains("ref=abcd1234"), true)
        XCTAssertEqual(mock.createdCoachIds, ["c1"])
    }

    func testUnpublishedProfileSetsPrompt() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = PlayerProfile(
            id: "p1", userId: "u1", familyUnitId: "f1", hashSlug: "ab12cd",
            vanitySlug: nil, isPublished: false, bio: nil, headerColor: "slate",
            showAcademics: true, showAthletic: true, showFilm: true, showSchools: true,
            createdAt: "", updatedAt: ""
        )
        let vm = SendProfileViewModel(service: mock, authManager: MockAuthManager())
        let url = await vm.shareURL(forCoachId: "c1")
        XCTAssertNil(url)
        XCTAssertTrue(vm.notPublishedPrompt)
    }
}
