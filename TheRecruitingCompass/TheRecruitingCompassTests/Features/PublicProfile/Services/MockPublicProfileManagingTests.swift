import XCTest
@testable import TheRecruitingCompass

final class MockPublicProfileManagingTests: XCTestCase {
    nonisolated deinit {}

    func testMockReturnsStubProfile() async throws {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = PlayerProfile(
            id: "p1", userId: "u1", familyUnitId: "f1", hashSlug: "ab12cd",
            vanitySlug: nil, isPublished: false, bio: nil, headerColor: "slate",
            showAcademics: true, showAthletic: true, showFilm: true, showSchools: true,
            createdAt: "", updatedAt: ""
        )
        let result = try await mock.fetchProfile(accessToken: "t")
        XCTAssertEqual(result?.hashSlug, "ab12cd")
    }

    func testMockRecordsUpdatePayload() async throws {
        let mock = MockPublicProfileManaging()
        try await mock.updateProfile(UpdateProfilePayload(isPublished: true), accessToken: "t")
        XCTAssertEqual(mock.updatedPayloads.count, 1)
        XCTAssertEqual(mock.updatedPayloads.first?.isPublished, true)
    }

    func testMockThrowsConfiguredError() async {
        let mock = MockPublicProfileManaging()
        mock.errorToThrow = PublicProfileAPIError.slugTaken
        do {
            _ = try await mock.createTrackingLink(coachId: "c1", accessToken: "t")
            XCTFail("expected throw")
        } catch let e as PublicProfileAPIError {
            XCTAssertEqual(e, .slugTaken)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
