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

    func testSaveWithReservedLocalSlugStillPersistsOtherFields() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = makeProfile()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        await vm.load()
        let payloadCountBefore = mock.updatedPayloads.count

        vm.vanitySlug = "admin"
        vm.isPublished = true
        vm.bio = "updated despite bad slug"
        await vm.save()

        XCTAssertEqual(mock.updatedPayloads.count, payloadCountBefore + 1)
        XCTAssertNotNil(vm.slugError)
        XCTAssertEqual(mock.updatedPayloads.last?.isPublished, true)
        XCTAssertEqual(mock.updatedPayloads.last?.bio, "updated despite bad slug")
        XCTAssertNil(mock.updatedPayloads.last?.vanitySlug)
    }

    func testValidateSlugFlagsReserved() async {
        let mock = MockPublicProfileManaging()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        vm.vanitySlug = "admin"
        vm.validateSlug()
        XCTAssertNotNil(vm.slugError)
    }

    func testAssembleCardGatesSectionsOnLiveToggles() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = makeProfile() // showAthletic: false, everything else: true

        let authManager = MockAuthManager()
        authManager.setMockUser(User(
            id: "u1", email: "jordan@example.com", emailConfirmedAt: nil, phone: nil,
            fullName: "Jordan Smith", createdAt: "", updatedAt: "", role: nil, dateOfBirth: nil
        ))

        let preferenceService = MockPreferenceService()
        preferenceService.stubbedPlayerDetails = PlayerDetails(
            graduationYear: 2027, highSchool: "Central High", gpa: 3.8, satScore: 1300
        )

        let videoLinksService = MockVideoLinksService()
        videoLinksService.links = [
            VideoLink(
                id: "v1", userId: "u1", familyUnitId: "f1", platform: .youtube,
                url: "https://youtube.com/x", title: "Highlights", position: 0,
                healthStatus: .unknown, lastHealthCheck: nil, createdAt: nil, updatedAt: nil
            )
        ]

        let schoolsService = MockSchoolsService()
        schoolsService.stubbedSchools = [makeSchool(id: "s1", name: "State U")]

        let photoService = MockProfilePhotoService()
        photoService.stubbedCurrentURL = "https://example.com/p.jpg"

        let vm = PublicProfileViewModel(
            service: mock,
            authManager: authManager,
            familyUnitId: "family-1",
            preferenceService: preferenceService,
            schoolsService: schoolsService,
            videoLinksService: videoLinksService,
            photoService: photoService
        )
        await vm.load()
        XCTAssertFalse(vm.showAthletic) // sanity: live toggle came from the loaded profile

        await vm.assembleCard()

        XCTAssertEqual(vm.cardData?.playerName, "Jordan Smith")
        XCTAssertEqual(vm.cardData?.photoUrl, "https://example.com/p.jpg")
        XCTAssertEqual(vm.cardData?.academics?.highSchool, "Central High")
        XCTAssertNil(vm.cardData?.athletic) // gated off: showAthletic is false
        XCTAssertEqual(vm.cardData?.film?.first?.title, "Highlights")
        XCTAssertEqual(vm.cardData?.schools?.first?.name, "State U")
    }

    private func makeSchool(id: String, name: String) -> School {
        School(
            id: id, userId: "u1", name: name, location: nil, city: nil, state: nil,
            division: nil, conference: nil, ranking: nil, isFavorite: false, website: nil,
            faviconUrl: nil, twitterHandle: nil, instagramHandle: nil, ncaaId: nil,
            status: "active", statusChangedAt: nil, notes: nil, pros: [], cons: [],
            offerDetails: nil, academicInfo: nil, amenities: nil, coachingPhilosophy: nil,
            coachingStyle: nil, recruitingApproach: nil, communicationStyle: nil,
            successMetrics: nil, fitScore: nil, fitTier: nil, familyUnitId: "family-1",
            createdBy: nil, updatedBy: nil, createdAt: "2025-01-01T00:00:00Z",
            updatedAt: "2025-01-01T00:00:00Z"
        )
    }
}
