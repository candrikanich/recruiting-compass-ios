import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SendProfileViewModelTests: XCTestCase {
    nonisolated deinit {}

    // MARK: - Fixtures

    private func makeProfile(userId: String = "u1", isPublished: Bool = true) -> PlayerProfile {
        PlayerProfile(
            id: "p1", userId: userId, familyUnitId: "f1", hashSlug: "ab12cd",
            vanitySlug: "owen", isPublished: isPublished, bio: nil, headerColor: "slate",
            showAcademics: true, showAthletic: true, showFilm: true, showSchools: true,
            createdAt: "", updatedAt: ""
        )
    }

    private func makeCoach(email: String? = nil, phone: String? = nil) -> Coach {
        Coach(
            id: "c1", firstName: "Jane", lastName: "Smith",
            email: email, phone: phone, schoolId: "s1",
            createdAt: "", updatedAt: ""
        )
    }

    private func makeVM(
        service: MockPublicProfileManaging,
        authManager: MockAuthManager,
        preference: MockPreferenceService = MockPreferenceService(),
        photo: MockProfilePhotoService = MockProfilePhotoService(),
        interactions: MockInteractionsService = MockInteractionsService(),
        familyManager: FamilyManager? = nil
    ) -> SendProfileViewModel {
        SendProfileViewModel(
            service: service, authManager: authManager,
            preferenceService: preference, photoService: photo, interactionsService: interactions,
            familyManager: familyManager ?? FamilyManager(familyService: MockFamilyService(), authManager: authManager)
        )
    }

    private func selfAuth(userId: String = "u1", fullName: String = "Owen Andrikanich") -> MockAuthManager {
        let auth = MockAuthManager()
        auth.setMockUser(User(
            id: userId, email: "o@x.com", emailConfirmedAt: nil,
            fullName: fullName, createdAt: "", updatedAt: "", role: nil, dateOfBirth: nil
        ))
        return auth
    }

    // MARK: - prepare: channel routing

    func testPrepareEmailOnlyReturnsEmailCaseWithTrackingURL() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile()
        service.stubTrackingLink = ProfileTrackingLink(
            id: "t1", profileId: "p1", coachId: "c1", refToken: "abcd1234",
            viewCount: 0, lastViewedAt: nil, createdAt: ""
        )
        let vm = makeVM(service: service, authManager: selfAuth())

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        guard case let .email(message) = result else {
            return XCTFail("expected .email, got \(result)")
        }
        XCTAssertTrue(message.url.absoluteString.contains("/p/owen"))
        XCTAssertTrue(message.url.absoluteString.contains("ref=abcd1234"))
        XCTAssertEqual(message.coachEmail, "coach@x.edu")
    }

    func testPreparePhoneOnlyReturnsTextCase() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile()
        let vm = makeVM(service: service, authManager: selfAuth())

        let result = await vm.prepare(for: makeCoach(phone: "5551234"))

        guard case .text = result else { return XCTFail("expected .text, got \(result)") }
    }

    func testPrepareBothReturnsChoiceCase() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile()
        let vm = makeVM(service: service, authManager: selfAuth())

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu", phone: "5551234"))

        guard case .choice = result else { return XCTFail("expected .choice, got \(result)") }
    }

    func testPrepareNoContactFallsBackToShare() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile()
        let vm = makeVM(service: service, authManager: selfAuth())

        let result = await vm.prepare(for: makeCoach())

        guard case let .share(url) = result else { return XCTFail("expected .share, got \(result)") }
        XCTAssertTrue(url.absoluteString.contains("/p/owen"))
    }

    func testPrepareUnpublishedReturnsNotPublishedAndSetsPrompt() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(isPublished: false)
        let vm = makeVM(service: service, authManager: selfAuth())

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        guard case .notPublished = result else { return XCTFail("expected .notPublished, got \(result)") }
        XCTAssertTrue(vm.notPublishedPrompt)
    }

    // MARK: - prepare: subject content

    func testPrepareSubjectIncludesGradYearNameAndPositions() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile()
        let preference = MockPreferenceService()
        var details = PlayerDetails()
        details.graduationYear = 2028
        details.primarySport = "baseball"
        details.positions = ["3B", "2B"]
        preference.stubbedPlayerDetails = details
        let vm = makeVM(service: service, authManager: selfAuth(), preference: preference)

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        guard case let .email(message) = result else { return XCTFail("expected .email") }
        XCTAssertEqual(message.subject, "2028 Owen Andrikanich Recruiting Profile (3B/2B)")
    }

    // MARK: - prepare: parent-sent name lookup

    func testPrepareParentUsesPhotoServiceNameForAthlete() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: ParentViewingAthleteFixture.athleteUserId)
        let photo = MockProfilePhotoService()
        photo.stubbedFullName = "Athlete Smith"
        let auth = MockAuthManager()
        let family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
        let vm = makeVM(service: service, authManager: auth, photo: photo, familyManager: family)

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        XCTAssertEqual(auth.user?.fullName, "Parent Smith")
        guard case let .email(message) = result else { return XCTFail("expected .email") }
        XCTAssertEqual(photo.lastFullNameUserId, ParentViewingAthleteFixture.athleteUserId)
        XCTAssertTrue(message.subject.contains("Athlete Smith"), message.subject)
        XCTAssertFalse(message.subject.contains("Parent Smith"), message.subject)
    }

    // MARK: - loadTrackingInfo (copy-link + view stats, web parity)

    func testLoadTrackingInfoExposesExistingLinkAndViewStats() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(isPublished: true)
        service.stubTrackingLink = ProfileTrackingLink(
            id: "t1", profileId: "p1", coachId: "c1", refToken: "abcd1234",
            viewCount: 7, lastViewedAt: "2026-08-20T00:00:00Z", createdAt: ""
        )
        let vm = makeVM(service: service, authManager: selfAuth())

        await vm.loadTrackingInfo(for: "c1")

        XCTAssertTrue(vm.isPublished)
        XCTAssertEqual(vm.viewCount, 7)
        XCTAssertEqual(vm.lastViewedAt, "2026-08-20T00:00:00Z")
        XCTAssertEqual(vm.trackingURL?.absoluteString.contains("/p/owen"), true)
        XCTAssertEqual(vm.trackingURL?.absoluteString.contains("ref=abcd1234"), true)
    }

    func testLoadTrackingInfoLeavesURLNilWhenNoLinkYet() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(isPublished: true)
        // stubTrackingLink stays nil -> fetchTrackingLink returns nil
        let vm = makeVM(service: service, authManager: selfAuth())

        await vm.loadTrackingInfo(for: "c1")

        XCTAssertTrue(vm.isPublished)
        XCTAssertNil(vm.trackingURL)
        XCTAssertNil(vm.viewCount)
    }

    // MARK: - athlete targeting (#422)

    private let athleteUserId = ParentViewingAthleteFixture.athleteUserId

    private func parentVM(service: MockPublicProfileManaging) -> SendProfileViewModel {
        let auth = MockAuthManager()
        let family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
        let photo = MockProfilePhotoService()
        photo.stubbedFullName = "Athlete Smith"
        return makeVM(service: service, authManager: auth, photo: photo, familyManager: family)
    }

    func testParentLoadTrackingInfoSendsAthleteIdOnProfileAndLink() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: athleteUserId)

        await parentVM(service: service).loadTrackingInfo(for: "c1")

        XCTAssertEqual(service.fetchedAthleteIds, [athleteUserId])
        XCTAssertEqual(service.fetchedTrackingAthleteIds, [athleteUserId])
    }

    func testParentPrepareSendsAthleteIdOnProfileAndTrackingLink() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: athleteUserId)

        let result = await parentVM(service: service).prepare(for: makeCoach(email: "coach@x.edu"))

        guard case .email = result else { return XCTFail("expected .email, got \(result)") }
        XCTAssertEqual(service.fetchedAthleteIds, [athleteUserId])
        XCTAssertEqual(service.createdTrackingAthleteIds, [athleteUserId])
    }

    func testPlayerPrepareSendsNoAthleteId() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile()

        _ = await makeVM(service: service, authManager: selfAuth()).prepare(for: makeCoach(email: "coach@x.edu"))

        XCTAssertEqual(service.fetchedAthleteIds, [nil])
        XCTAssertEqual(service.createdTrackingAthleteIds, [nil])
    }

    func testPlayerLoadTrackingInfoSendsNoAthleteId() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile()

        await makeVM(service: service, authManager: selfAuth()).loadTrackingInfo(for: "c1")

        XCTAssertEqual(service.fetchedAthleteIds, [nil])
        XCTAssertEqual(service.fetchedTrackingAthleteIds, [nil])
    }

    func testParentWithoutSelectedAthleteNeverCallsServiceAndFails() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: "someone-else")
        let auth = MockAuthManager()
        let family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
        family.selectedAthleteId = nil
        let vm = makeVM(service: service, authManager: auth, familyManager: family)

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
        XCTAssertTrue(service.fetchedAthleteIds.isEmpty)
        XCTAssertTrue(service.createdTrackingAthleteIds.isEmpty)
    }

    func testParentNeverSendsProfileOfADifferentAthleteThanSelected() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: "other-athlete")   // server returned a different athlete's row

        let result = await parentVM(service: service).prepare(for: makeCoach(email: "coach@x.edu"))

        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
        XCTAssertTrue(service.createdTrackingAthleteIds.isEmpty)
    }

    // MARK: - #422 rework: guards

    func testPlayerWithUppercaseSessionIdStillSends() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: "abcdef01-aaaa-bbbb-cccc-000000000001")
        let auth = selfAuth(userId: "ABCDEF01-AAAA-BBBB-CCCC-000000000001")

        let result = await makeVM(service: service, authManager: auth).prepare(for: makeCoach(email: "c@x.edu"))

        guard case .email = result else { return XCTFail("expected .email, got \(result)") }
        XCTAssertEqual(service.fetchedAthleteIds, [nil])
        XCTAssertEqual(service.createdTrackingAthleteIds, [nil])
    }

    func testPlayerWithUppercaseSessionIdLoadsTrackingInfo() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: "abcdef01-aaaa-bbbb-cccc-000000000001")
        service.stubTrackingLink = ProfileTrackingLink(
            id: "t1", profileId: "p1", coachId: "c1", refToken: "tok", viewCount: 1, lastViewedAt: nil, createdAt: ""
        )
        let auth = selfAuth(userId: "ABCDEF01-AAAA-BBBB-CCCC-000000000001")

        let vm = makeVM(service: service, authManager: auth)
        await vm.loadTrackingInfo(for: "c1")

        XCTAssertNotNil(vm.trackingURL)
    }

    func testLoadTrackingInfoRefusesAnotherAthletesProfileForParent() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: "other-athlete")
        service.stubTrackingLink = ProfileTrackingLink(
            id: "t1", profileId: "p1", coachId: "c1", refToken: "tok", viewCount: 9, lastViewedAt: nil, createdAt: ""
        )

        let vm = parentVM(service: service)
        await vm.loadTrackingInfo(for: "c1")

        XCTAssertNil(vm.trackingURL)
        XCTAssertNil(vm.viewCount)
        XCTAssertFalse(vm.isPublished)
        XCTAssertTrue(service.fetchedTrackingAthleteIds.isEmpty)
    }

    func testLoadTrackingInfoRefusesAnotherUsersProfileForPlayer() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: "someone-else")
        service.stubTrackingLink = ProfileTrackingLink(
            id: "t1", profileId: "p1", coachId: "c1", refToken: "tok", viewCount: 9, lastViewedAt: nil, createdAt: ""
        )

        let vm = makeVM(service: service, authManager: selfAuth())
        await vm.loadTrackingInfo(for: "c1")

        XCTAssertNil(vm.trackingURL)
        XCTAssertFalse(vm.isPublished)
        XCTAssertTrue(service.fetchedTrackingAthleteIds.isEmpty)
    }

    func testPlayerPrepareRefusesAnotherUsersProfile() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: "someone-else")

        let result = await makeVM(service: service, authManager: selfAuth()).prepare(for: makeCoach(email: "c@x.edu"))

        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
        XCTAssertTrue(service.createdTrackingAthleteIds.isEmpty)
    }

    func testFailedLoadClearsPreviousAthletesLinkAndStats() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile()
        service.stubTrackingLink = ProfileTrackingLink(
            id: "t1", profileId: "p1", coachId: "c1", refToken: "tok", viewCount: 4,
            lastViewedAt: "2026-08-20T00:00:00Z", createdAt: ""
        )
        let vm = makeVM(service: service, authManager: selfAuth())
        await vm.loadTrackingInfo(for: "c1")
        XCTAssertNotNil(vm.trackingURL)

        service.stubProfile = makeProfile(userId: "someone-else")
        await vm.loadTrackingInfo(for: "c1")

        XCTAssertNil(vm.trackingURL)
        XCTAssertNil(vm.viewCount)
        XCTAssertNil(vm.lastViewedAt)
        XCTAssertFalse(vm.isPublished)
    }

    func testSelectionKeyFollowsSelectedAthlete() {
        let auth = MockAuthManager()
        let family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
        let vm = makeVM(service: MockPublicProfileManaging(), authManager: auth, familyManager: family)
        XCTAssertEqual(vm.selectionKey, athleteUserId)

        family.selectedAthleteId = nil

        XCTAssertEqual(vm.selectionKey, "")
    }

    func testSelectionChangedMidFlightNeverSendsForTheNewSelection() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: athleteUserId)
        let auth = MockAuthManager()
        let family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
        let photo = MockProfilePhotoService()
        photo.stubbedFullName = "Athlete Smith"
        service.onCreateTrackingLink = { family.selectedAthleteId = nil }
        let vm = makeVM(service: service, authManager: auth, photo: photo, familyManager: family)

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
        XCTAssertNil(vm.trackingURL)
    }

    func testFailedPrepareSetsVisibleErrorMessage() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = nil
        let vm = makeVM(service: service, authManager: selfAuth())

        let result = await vm.prepare(for: makeCoach(email: "c@x.edu"))

        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
        XCTAssertNotNil(vm.errorMessage)
    }

    func testParentWithUnresolvableAthleteNameNeverSendsBlankName() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: athleteUserId)
        let auth = MockAuthManager()
        let family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
        let vm = makeVM(service: service, authManager: auth, photo: MockProfilePhotoService(), familyManager: family)

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(service.createdTrackingAthleteIds.isEmpty)
    }

    // MARK: - #422 round 2: stale state, name fallback

    private typealias Fixture = ParentViewingAthleteFixture

    private func link(views: Int = 3) -> ProfileTrackingLink {
        ProfileTrackingLink(
            id: "t1", profileId: "p1", coachId: "c1", refToken: "tok", viewCount: views,
            lastViewedAt: "2026-08-20T00:00:00Z", createdAt: ""
        )
    }

    private func parentSetup(
        service: MockPublicProfileManaging
    ) -> (vm: SendProfileViewModel, family: FamilyManager) {
        let auth = MockAuthManager()
        let family = Fixture.makeFamilyManager(authManager: auth)
        let photo = MockProfilePhotoService()
        photo.stubbedFullName = "Athlete Smith"
        return (makeVM(service: service, authManager: auth, photo: photo, familyManager: family), family)
    }

    func testStaleFailedLoadDoesNotClearTheNewSelectionsState() async {
        let service = MockPublicProfileManaging()
        service.stubTrackingLink = link()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let (vm, family) = parentSetup(service: service)
        service.onFetchProfile = { [unowned service] in
            service.onFetchProfile = nil
            Fixture.selectSecondAthlete(in: family)
            service.stubProfile = self.makeProfile(userId: Fixture.secondAthleteUserId)
            await vm.loadTrackingInfo(for: "c1")
            service.stubProfile = nil   // the first (now stale) load fails
        }

        await vm.loadTrackingInfo(for: "c1")

        XCTAssertNotNil(vm.trackingURL)
        XCTAssertTrue(vm.isPublished)
    }

    func testStaleSuccessfulLoadIsDiscardedAfterSelectionChange() async {
        let service = MockPublicProfileManaging()
        service.stubTrackingLink = link()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let (vm, family) = parentSetup(service: service)
        service.onFetchTrackingLink = { Fixture.selectSecondAthlete(in: family) }

        await vm.loadTrackingInfo(for: "c1")

        XCTAssertNil(vm.trackingURL)
        XCTAssertNil(vm.viewCount)
        XCTAssertFalse(vm.isPublished)
    }

    func testReloadWithoutALinkClearsThePreviousLinkAndStats() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile()
        service.stubTrackingLink = link()
        let vm = makeVM(service: service, authManager: selfAuth())
        await vm.loadTrackingInfo(for: "c1")
        XCTAssertNotNil(vm.trackingURL)

        service.stubTrackingLink = nil
        await vm.loadTrackingInfo(for: "c1")

        XCTAssertNil(vm.trackingURL)
        XCTAssertNil(vm.viewCount)
        XCTAssertNil(vm.lastViewedAt)
        XCTAssertTrue(vm.isPublished)
    }

    func testSwitchingAthleteClearsLinkBeforeTheReloadAwaits() async {
        let service = MockPublicProfileManaging()
        service.stubTrackingLink = link()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let (vm, family) = parentSetup(service: service)
        await vm.loadTrackingInfo(for: "c1")
        XCTAssertNotNil(vm.trackingURL)

        Fixture.selectSecondAthlete(in: family)
        service.stubProfile = makeProfile(userId: Fixture.secondAthleteUserId)
        var seenMidFlight: (URL?, Int?, Bool)?
        service.onFetchProfile = { seenMidFlight = (vm.trackingURL, vm.viewCount, vm.isPublished) }
        await vm.loadTrackingInfo(for: "c1")

        XCTAssertNil(seenMidFlight?.0)
        XCTAssertNil(seenMidFlight?.1)
        XCTAssertEqual(seenMidFlight?.2, false)
    }

    func testCopyLinkDoesNotCopyThePreviousAthletesLinkAfterSwitching() async {
        let service = MockPublicProfileManaging()
        service.stubTrackingLink = link()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let (vm, family) = parentSetup(service: service)
        await vm.loadTrackingInfo(for: "c1")
        Fixture.selectSecondAthlete(in: family)
        UIPasteboard.general.string = "sentinel"

        vm.copyTrackingLink()

        XCTAssertEqual(UIPasteboard.general.string, "sentinel")
    }

    func testPlayerWithEmptySessionNameFallsBackToProfileName() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile()
        let photo = MockProfilePhotoService()
        photo.stubbedFullName = "Owen Lookup"
        let vm = makeVM(service: service, authManager: selfAuth(fullName: ""), photo: photo)

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        guard case let .email(message) = result else { return XCTFail("expected .email, got \(result)") }
        XCTAssertTrue(message.subject.contains("Owen Lookup"), message.subject)
    }

    func testPlayerWithBlankSessionAndLookupNamesIsRefused() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile()
        let photo = MockProfilePhotoService()
        photo.stubbedFullName = " \n"
        let vm = makeVM(service: service, authManager: selfAuth(fullName: "\n"), photo: photo)

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
        XCTAssertTrue(service.createdTrackingAthleteIds.isEmpty)
    }

    // MARK: - logSend (interaction logging on confirmed send only)

    func testLogSendEmailCreatesOutboundEmailInteraction() async {
        let interactions = MockInteractionsService()
        let vm = makeVM(service: MockPublicProfileManaging(), authManager: selfAuth(), interactions: interactions)
        let message = SendProfileMessage(
            coachId: "c1", schoolId: "s1", familyUnitId: "f1",
            coachEmail: "coach@x.edu", coachPhone: nil,
            subject: "2028 Owen Andrikanich Recruiting Profile (3B/2B)",
            emailBody: "body", textBody: "text",
            url: URL(string: "https://app.example.com/p/owen?ref=abcd1234")!
        )

        await vm.logSend(.email, message: message)

        XCTAssertEqual(interactions.createInteractionCallCount, 1)
        let request = interactions.lastCreatedInteractionRequest
        XCTAssertEqual(request?.type, "email")
        XCTAssertEqual(request?.direction, "outbound")
        XCTAssertEqual(request?.coachId, "c1")
        XCTAssertEqual(request?.schoolId, "s1")
        XCTAssertEqual(request?.familyUnitId, "f1")
        XCTAssertEqual(request?.content, "https://app.example.com/p/owen?ref=abcd1234")
    }

    func testLogSendTextCreatesTextInteraction() async {
        let interactions = MockInteractionsService()
        let vm = makeVM(service: MockPublicProfileManaging(), authManager: selfAuth(), interactions: interactions)
        let message = SendProfileMessage(
            coachId: "c1", schoolId: "s1", familyUnitId: "f1",
            coachEmail: nil, coachPhone: "5551234",
            subject: "subj", emailBody: "body", textBody: "text",
            url: URL(string: "https://app.example.com/p/owen?ref=abcd1234")!
        )

        await vm.logSend(.text, message: message)

        XCTAssertEqual(interactions.lastCreatedInteractionRequest?.type, "text")
    }
}
