import XCTest
@testable import TheRecruitingCompass

@MainActor
final class PublicProfileViewModelTests: XCTestCase {
    nonisolated deinit {}

    private func makeProfile(published: Bool = false, slug: String? = nil) -> PlayerProfile {
        PlayerProfile(
            id: "p1", userId: "u1", familyUnitId: "f1", hashSlug: "ab12cd",
            vanitySlug: slug, isPublished: published, bio: "hi", headerColor: "blue",
            showAcademics: true, showAthletic: false, showFilm: true, showSchools: true,
            createdAt: "", updatedAt: ""
        )
    }

    func testLoadPopulatesEditorState() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = makeProfile(published: true, slug: "jordan")
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        await vm.load()
        XCTAssertTrue(vm.isPublished)
        XCTAssertEqual(vm.vanitySlug, "jordan")
        XCTAssertEqual(vm.headerColor, .blue)
        XCTAssertFalse(vm.showAthletic)
    }

    func testSaveSendsCurrentState() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = makeProfile()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        await vm.load()
        vm.isPublished = true
        vm.bio = "updated"
        await vm.save()
        XCTAssertEqual(mock.updatedPayloads.last?.isPublished, true)
        XCTAssertEqual(mock.updatedPayloads.last?.bio, "updated")
    }

    func testSaveMapsSlugTakenToError() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = makeProfile()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        await vm.load()
        mock.errorToThrow = PublicProfileAPIError.slugTaken
        vm.vanitySlug = "taken"
        await vm.save()
        XCTAssertNotNil(vm.slugError)
    }

    func testValidateSlugFlagsReserved() async {
        let mock = MockPublicProfileManaging()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        vm.vanitySlug = "admin"
        vm.validateSlug()
        XCTAssertNotNil(vm.slugError)
    }
}
