import XCTest
@testable import TheRecruitingCompass

@MainActor
final class PublicProfileViewModelTests: XCTestCase {
    nonisolated deinit {}

    private func makeProfile(
        published: Bool = false, slug: String? = nil,
        sectionConfig: [ProfileSection] = DefaultSectionOrder.keys.map { ProfileSection(key: $0, visible: true) }
    ) -> PlayerProfile {
        PlayerProfile(
            id: "p1", userId: "u1", familyUnitId: "f1", hashSlug: "ab12cd",
            vanitySlug: slug, isPublished: published, bio: "hi", headerColor: "blue",
            sectionConfig: sectionConfig,
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

    func testSaveSurfacesServerErrorMessage() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = makeProfile()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        await vm.load()
        mock.errorToThrow = PublicProfileAPIError.server(500)
        await vm.save()
        XCTAssertNotNil(vm.saveError)
    }

    func testSaveSurfacesNotMemberErrorMessage() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = makeProfile()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        await vm.load()
        mock.errorToThrow = PublicProfileAPIError.notMember
        await vm.save()
        XCTAssertNotNil(vm.saveError)
    }

    func testSaveClearsPreviousSaveErrorOnSuccess() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = makeProfile()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        await vm.load()
        mock.errorToThrow = PublicProfileAPIError.server(500)
        await vm.save()
        XCTAssertNotNil(vm.saveError)
        mock.errorToThrow = nil
        await vm.save()
        XCTAssertNil(vm.saveError)
    }

    func testAssembleCardLooksUpTargetNameWhenNotSelf() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = makeProfile()

        let authManager = MockAuthManager()
        authManager.setMockUser(User(
            id: "parent-1", email: "parent@example.com", emailConfirmedAt: nil, phone: nil,
            fullName: "Parent Smith", createdAt: "", updatedAt: "", role: nil, dateOfBirth: nil
        ))

        let photoService = MockProfilePhotoService()
        photoService.stubbedFullName = "Athlete Smith"

        let vm = PublicProfileViewModel(
            service: mock,
            authManager: authManager,
            targetUserId: "athlete-9",
            preferenceService: MockPreferenceService(),
            schoolsService: MockSchoolsService(),
            videoLinksService: MockVideoLinksService(),
            photoService: photoService,
            performanceService: MockPerformanceService()
        )
        await vm.load()
        await vm.assembleCard()

        XCTAssertEqual(vm.cardData?.playerName, "Athlete Smith")
        XCTAssertEqual(photoService.lastFullNameUserId, "athlete-9")
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
        mock.stubProfile = makeProfile(sectionConfig: [
            ProfileSection(key: .metrics, visible: true),
            ProfileSection(key: .film, visible: true),
            ProfileSection(key: .academics, visible: true),
            ProfileSection(key: .values, visible: true),
            ProfileSection(key: .teamHistory, visible: false),
            ProfileSection(key: .awards, visible: true)
        ])

        let authManager = MockAuthManager()
        authManager.setMockUser(User(
            id: "u1", email: "jordan@example.com", emailConfirmedAt: nil, phone: nil,
            fullName: "Jordan Smith", createdAt: "", updatedAt: "", role: nil, dateOfBirth: nil
        ))

        let preferenceService = MockPreferenceService()
        preferenceService.stubbedPlayerDetails = PlayerDetails(
            graduationYear: 2027, highSchool: "Central High", gpa: 3.8, satScore: 1300,
            twelfthGradeTeam: "Central HS Varsity", twelfthGradeCoach: "Coach Lee"
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

        let performanceService = MockPerformanceService()
        performanceService.mockMetrics = [
            performanceService.createTestMetric(metricType: .battingAvg, value: 0.41, verified: true)
        ]

        let vm = PublicProfileViewModel(
            service: mock,
            authManager: authManager,
            familyUnitId: "family-1",
            preferenceService: preferenceService,
            schoolsService: schoolsService,
            videoLinksService: videoLinksService,
            photoService: photoService,
            performanceService: performanceService
        )
        await vm.load()
        XCTAssertFalse(vm.isSectionVisible(.teamHistory)) // sanity: live section came from the loaded profile

        await vm.assembleCard()

        XCTAssertEqual(vm.cardData?.playerName, "Jordan Smith")
        XCTAssertEqual(vm.cardData?.photoUrl, "https://example.com/p.jpg")
        XCTAssertEqual(vm.cardData?.academics?.highSchool, "Central High")
        XCTAssertNil(vm.cardData?.teamHistory) // gated off: team_history section is hidden
        XCTAssertEqual(vm.cardData?.film?.first?.title, "Highlights")
        XCTAssertEqual(vm.cardData?.metrics?.first?.value, ".410")
    }

    func testToggleSectionVisibilityFlipsSingleKey() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = makeProfile()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        await vm.load()
        XCTAssertTrue(vm.isSectionVisible(.awards))
        vm.toggleSectionVisibility(.awards)
        XCTAssertFalse(vm.isSectionVisible(.awards))
    }

    func testMoveSectionsReordersArray() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = makeProfile()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        await vm.load()
        XCTAssertEqual(vm.sections.first?.key, .metrics)
        vm.moveSections(fromOffsets: IndexSet(integer: 0), toOffset: vm.sections.count)
        XCTAssertNotEqual(vm.sections.first?.key, .metrics)
    }

    func testAddAndRemoveValueTag() {
        let mock = MockPublicProfileManaging()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        vm.addValueTag("Academics")
        XCTAssertEqual(vm.valuesTags, ["Academics"])
        vm.removeValueTag("Academics")
        XCTAssertTrue(vm.valuesTags.isEmpty)
    }

    func testValueTagCapAtTwelve() {
        let mock = MockPublicProfileManaging()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        for index in 0..<12 { vm.addValueTag("tag\(index)") }
        vm.addValueTag("overflow")
        XCTAssertEqual(vm.valuesTags.count, 12)
    }

    func testAddAndRemoveAward() {
        let mock = MockPublicProfileManaging()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        vm.addAward(title: "All-Conference", year: 2026)
        XCTAssertEqual(vm.awards.first?.title, "All-Conference")
        vm.removeAward(vm.awards[0])
        XCTAssertTrue(vm.awards.isEmpty)
    }

    func testBuildMetricsDedupesByTypeKeepingNewest() {
        let older = PerformanceMetric(
            id: "1", userId: "u1", metricType: .exitVelo, value: 85, unit: "mph",
            recordedDate: Date(), eventId: nil, verified: false, notes: nil,
            createdAt: Date(timeIntervalSince1970: 100), updatedAt: Date(timeIntervalSince1970: 100)
        )
        let newer = PerformanceMetric(
            id: "2", userId: "u1", metricType: .exitVelo, value: 91, unit: "mph",
            recordedDate: Date(), eventId: nil, verified: true, notes: nil,
            createdAt: Date(timeIntervalSince1970: 200), updatedAt: Date(timeIntervalSince1970: 200)
        )
        let entries = PublicProfileViewModel.buildMetrics(from: [older, newer])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.value, "91.0")
        XCTAssertTrue(entries.first?.verified ?? false)
    }

    func testBuildMetricsCapsAtSixRankingPrimaryVerifiedFirst() {
        var rows: [PerformanceMetric] = []
        for index in 0..<8 {
            let key: String = "metric_\(index)"
            let value: Double = Double(index)
            let isVerified: Bool = index == 0
            let isPrimary: Bool = index == 1
            let created: Date = Date(timeIntervalSince1970: Double(index))
            let row = PerformanceMetric(
                id: "\(index)", userId: "u1", metricType: MetricType(rawValue: key),
                value: value, unit: "", recordedDate: Date(), eventId: nil,
                verified: isVerified, notes: nil, isPrimary: isPrimary,
                createdAt: created, updatedAt: Date()
            )
            rows.append(row)
        }
        let entries = PublicProfileViewModel.buildMetrics(from: rows)
        XCTAssertEqual(entries.count, 6)
        XCTAssertEqual(entries.first?.key, "metric_1") // isPrimary ranks first
    }

    func testBuildTeamHistoryIncludesGradeTeamsAndTravelTeams() {
        var details = PlayerDetails()
        details.twelfthGradeTeam = "Central HS Varsity"
        details.twelfthGradeCoach = "Coach Lee"
        details.travelTeams = [TravelTeam(year: 2025, name: "Elite Travel", coach: "Coach Diaz")]

        let entries = PublicProfileViewModel.buildTeamHistory(from: details)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].name, "Central HS Varsity")
        XCTAssertEqual(entries[0].level, "12th Grade")
        XCTAssertNil(entries[0].contact)
        XCTAssertEqual(entries[1].name, "Elite Travel")
        XCTAssertEqual(entries[1].level, "Travel")
    }

    private func makeSchool(id: String, name: String) -> School {
        School(
            id: id, userId: "u1", name: name, location: nil, city: nil, state: nil,
            division: nil, conference: nil, ranking: nil, isFavorite: false, website: nil,
            faviconUrl: nil, twitterHandle: nil, instagramHandle: nil, ncaaId: nil,
            status: "active", statusChangedAt: nil, notes: nil, pros: [], cons: [],
            offerDetails: nil, academicInfo: nil, amenities: nil, coachingPhilosophy: nil,
            coachingStyle: nil, recruitingApproach: nil, communicationStyle: nil,
            successMetrics: nil, familyUnitId: "family-1",
            createdBy: nil, updatedBy: nil, createdAt: "2025-01-01T00:00:00Z",
            updatedAt: "2025-01-01T00:00:00Z"
        )
    }
}
