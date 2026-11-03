import XCTest
@testable import TheRecruitingCompass

/// Stale-state, generation and failure-path guards for `SendProfileViewModel` (#422). Shared fixtures live in
/// `SendProfileViewModelTests`.
extension SendProfileViewModelTests {
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

    func testCopyLinkCopiesTheLoadedLinkAndReportsSuccess() async {
        let service = MockPublicProfileManaging()
        service.stubTrackingLink = link()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let (vm, _) = parentSetup(service: service)
        await vm.loadTrackingInfo(for: "c1")
        UIPasteboard.general.string = "sentinel"

        XCTAssertTrue(vm.copyTrackingLink())

        XCTAssertEqual(UIPasteboard.general.string, vm.trackingURL?.absoluteString)
        XCTAssertNotEqual(UIPasteboard.general.string, "sentinel")
    }

    func testCopyLinkReportsRefusalForAnotherAthletesLink() async {
        let service = MockPublicProfileManaging()
        service.stubTrackingLink = link()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let (vm, family) = parentSetup(service: service)
        await vm.loadTrackingInfo(for: "c1")
        Fixture.selectSecondAthlete(in: family)

        XCTAssertFalse(vm.copyTrackingLink())
    }

    func testCopyLinkReportsFailureWhenNothingIsLoaded() {
        let vm = makeVM(service: MockPublicProfileManaging(), authManager: selfAuth())

        XCTAssertFalse(vm.copyTrackingLink())
    }

    func testStaleSameAthleteLoadResolvingLastCannotWipeTheLatestLoad() async {
        let service = MockPublicProfileManaging()
        service.stubTrackingLink = link()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let (vm, family) = parentSetup(service: service)
        var firstLoadResume: CheckedContinuation<Void, Never>?
        service.onFetchProfile = { [unowned service] in
            service.onFetchProfile = nil
            await withCheckedContinuation { firstLoadResume = $0 }
        }
        let firstLoad = Task { await vm.loadTrackingInfo(for: "c1") }
        while firstLoadResume == nil { await Task.yield() }

        Fixture.selectSecondAthlete(in: family)
        family.selectedAthleteId = "member-athlete-1"   // A -> B -> A
        await vm.loadTrackingInfo(for: "c1")
        XCTAssertNotNil(vm.trackingURL)

        service.stubProfile = nil   // the stale first load now fails
        firstLoadResume?.resume()
        await firstLoad.value

        XCTAssertNotNil(vm.trackingURL)
        XCTAssertTrue(vm.isPublished)
    }

    // MARK: - #422 round 4

    /// Parks the next `fetchProfile` until `release()`; `waitUntilParked()` returns once it is suspended.
    private func parkNextProfileFetch(
        _ service: MockPublicProfileManaging
    ) -> (waitUntilParked: () async -> Void, release: () -> Void) {
        var resume: CheckedContinuation<Void, Never>?
        service.onFetchProfile = { [unowned service] in
            service.onFetchProfile = nil
            await withCheckedContinuation { resume = $0 }
        }
        return (
            { while resume == nil { await Task.yield() } },
            { resume?.resume() }
        )
    }

    func testStaleLoadWhoseLinkFetchComesBackEmptyCannotWipeTheNewerLoadsLink() async {
        let service = MockPublicProfileManaging()
        service.stubTrackingLink = link()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let (vm, _) = parentSetup(service: service)
        let parked = parkNextProfileFetch(service)
        let firstLoad = Task { await vm.loadTrackingInfo(for: "c1") }
        await parked.waitUntilParked()

        await vm.loadTrackingInfo(for: "c1")
        XCTAssertNotNil(vm.trackingURL)

        service.stubTrackingLink = nil   // the stale load's profile fetch succeeds, its link fetch is empty
        parked.release()
        await firstLoad.value

        XCTAssertNotNil(vm.trackingURL)
        XCTAssertEqual(vm.viewCount, 3)
    }

    func testInFlightLoadCannotWipeTheLinkASendJustCreated() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)   // no existing link
        let (vm, _) = parentSetup(service: service)
        let parked = parkNextProfileFetch(service)
        let load = Task { await vm.loadTrackingInfo(for: "c1") }
        await parked.waitUntilParked()

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))
        guard case .email = result else { return XCTFail("expected .email, got \(result)") }
        XCTAssertNotNil(vm.trackingURL)

        parked.release()
        await load.value

        XCTAssertNotNil(vm.trackingURL)
    }

    func testSelectionChangedWhileProfileFetchIsInFlightNeverMarksPublishedOrPrompts() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId, isPublished: false)
        let (vm, family) = parentSetup(service: service)
        service.onFetchProfile = { Fixture.selectSecondAthlete(in: family) }

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
        XCTAssertFalse(vm.notPublishedPrompt)
        XCTAssertFalse(vm.isPublished)
    }

    func testSelectionChangedDuringPublishedProfileFetchDoesNotMarkPublished() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let (vm, family) = parentSetup(service: service)
        service.onFetchProfile = { Fixture.selectSecondAthlete(in: family) }

        _ = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        XCTAssertFalse(vm.isPublished)
    }

    func testSelectionChangedDuringGuardianLookupNeverPromptsForTheOldAthlete() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let auth = MockAuthManager()
        let family = Fixture.makeFamilyManager(authManager: auth)
        auth.setMockSession(Session(
            accessToken: "t", tokenType: "bearer", expiresIn: 3600, expiresAt: 0,
            refreshToken: "r", user: Fixture.parentUser()
        ))
        let guardian = MockGuardianService()
        guardian.mockStatus = GuardianStatus(locked: true, guardianEmailMasked: nil, expiresAt: nil, status: nil)
        guardian.onFetchStatus = { Fixture.selectSecondAthlete(in: family) }
        let vm = SendProfileViewModel(
            service: service, authManager: auth, preferenceService: MockPreferenceService(),
            photoService: MockProfilePhotoService(), interactionsService: MockInteractionsService(),
            guardianService: guardian, familyManager: family
        )

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
        XCTAssertFalse(vm.guardianPendingPrompt)
    }

    func testCopiedStateDoesNotFollowTheUserToTheNextAthlete() async {
        let service = MockPublicProfileManaging()
        service.stubTrackingLink = link()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let (vm, family) = parentSetup(service: service)
        await vm.loadTrackingInfo(for: "c1")
        XCTAssertTrue(vm.copyTrackingLink())
        XCTAssertTrue(vm.linkCopied)

        Fixture.selectSecondAthlete(in: family)
        service.stubProfile = makeProfile(userId: Fixture.secondAthleteUserId)
        await vm.loadTrackingInfo(for: "c1")

        XCTAssertFalse(vm.linkCopied)
    }

    /// Parks the next `fetchTrackingLink` until `release()`.
    private func parkNextLinkFetch(
        _ service: MockPublicProfileManaging
    ) -> (waitUntilParked: () async -> Void, release: () -> Void) {
        var resume: CheckedContinuation<Void, Never>?
        service.onFetchTrackingLink = { [unowned service] in
            service.onFetchTrackingLink = nil
            await withCheckedContinuation { resume = $0 }
        }
        return (
            { while resume == nil { await Task.yield() } },
            { resume?.resume() }
        )
    }

    func testLoadStartedWhileASendIsInFlightCannotWipeTheLinkTheSendWrites() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)   // no existing link
        let (vm, _) = parentSetup(service: service)
        let sendParked = parkNextProfileFetch(service)
        let send = Task { await vm.prepare(for: makeCoach(email: "coach@x.edu")) }
        await sendParked.waitUntilParked()
        let linkParked = parkNextLinkFetch(service)
        let midSendLoad = Task { await vm.loadTrackingInfo(for: "c1") }
        await linkParked.waitUntilParked()

        sendParked.release()
        _ = await send.value
        XCTAssertNotNil(vm.trackingURL)
        linkParked.release()
        await midSendLoad.value

        XCTAssertNotNil(vm.trackingURL)
    }

    func testSendThatReturnsEarlyDoesNotDiscardAnInFlightLoad() async {
        let service = MockPublicProfileManaging()
        service.stubTrackingLink = link()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let (vm, _) = parentSetup(service: service)
        let linkParked = parkNextLinkFetch(service)
        let load = Task { await vm.loadTrackingInfo(for: "c1") }
        await linkParked.waitUntilParked()

        service.stubProfile = makeProfile(userId: Fixture.athleteUserId, isPublished: false)
        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))
        guard case .notPublished = result else { return XCTFail("expected .notPublished, got \(result)") }
        linkParked.release()
        await load.value

        XCTAssertNotNil(vm.trackingURL)
        XCTAssertEqual(vm.viewCount, 3)
    }

    /// Parks the next `createTrackingLink` until `release()`.
    private func parkNextCreate(
        _ service: MockPublicProfileManaging
    ) -> (waitUntilParked: () async -> Void, release: () -> Void) {
        var resume: CheckedContinuation<Void, Never>?
        service.onCreateTrackingLink = { [unowned service] in
            service.onCreateTrackingLink = nil
            await withCheckedContinuation { resume = $0 }
        }
        return (
            { while resume == nil { await Task.yield() } },
            { resume?.resume() }
        )
    }

    func testLoadStartedDuringLinkCreationCannotWipeTheLinkTheSendWrites() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)   // no existing link
        let (vm, _) = parentSetup(service: service)
        let createParked = parkNextCreate(service)
        let send = Task { await vm.prepare(for: makeCoach(email: "coach@x.edu")) }
        await createParked.waitUntilParked()
        let linkParked = parkNextLinkFetch(service)
        let duringCreateLoad = Task { await vm.loadTrackingInfo(for: "c1") }
        await linkParked.waitUntilParked()

        createParked.release()
        _ = await send.value
        XCTAssertNotNil(vm.trackingURL)
        linkParked.release()
        await duringCreateLoad.value

        XCTAssertNotNil(vm.trackingURL)
    }

    func testSendAbortedBySelectionChangeLeavesTheNewAthletesInFlightLoadAlone() async {
        let service = MockPublicProfileManaging()
        service.stubTrackingLink = link()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let (vm, family) = parentSetup(service: service)
        let createParked = parkNextCreate(service)
        let send = Task { await vm.prepare(for: makeCoach(email: "coach@x.edu")) }
        await createParked.waitUntilParked()

        Fixture.selectSecondAthlete(in: family)
        service.stubProfile = makeProfile(userId: Fixture.secondAthleteUserId)
        let linkParked = parkNextLinkFetch(service)
        let newAthleteLoad = Task { await vm.loadTrackingInfo(for: "c1") }
        await linkParked.waitUntilParked()

        createParked.release()
        let result = await send.value
        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
        linkParked.release()
        await newAthleteLoad.value

        XCTAssertNotNil(vm.trackingURL)
        XCTAssertEqual(vm.viewCount, 3)
    }

    /// Runs `prepare()` with an early-return condition set while a valid load is parked, then lets the load finish.
    private func prepareReturningEarlyLeavesInFlightLoadAlone(
        guardianLocked: Bool = false,
        athleteName: String? = "Athlete Smith",
        createFails: Bool = false,
        expectation: (SendProfilePreparation) -> Bool,
        file: StaticString = #filePath, line: UInt = #line
    ) async {
        let service = MockPublicProfileManaging()
        service.stubTrackingLink = link()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        if createFails { service.createTrackingLinkError = URLError(.notConnectedToInternet) }
        let auth = MockAuthManager()
        let family = Fixture.makeFamilyManager(authManager: auth)
        auth.setMockSession(Session(
            accessToken: "t", tokenType: "bearer", expiresIn: 3600, expiresAt: 0,
            refreshToken: "r", user: Fixture.parentUser()
        ))
        let guardian = MockGuardianService()
        guardian.mockStatus = GuardianStatus(
            locked: guardianLocked, guardianEmailMasked: nil, expiresAt: nil, status: nil
        )
        let photo = MockProfilePhotoService()
        photo.stubbedFullName = athleteName
        let vm = SendProfileViewModel(
            service: service, authManager: auth, preferenceService: MockPreferenceService(),
            photoService: photo, interactionsService: MockInteractionsService(),
            guardianService: guardian, familyManager: family
        )
        let linkParked = parkNextLinkFetch(service)
        let load = Task { await vm.loadTrackingInfo(for: "c1") }
        await linkParked.waitUntilParked()

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))
        XCTAssertTrue(expectation(result), "unexpected result \(result)", file: file, line: line)
        linkParked.release()
        await load.value

        XCTAssertNotNil(vm.trackingURL, file: file, line: line)
        XCTAssertEqual(vm.viewCount, 3, file: file, line: line)
    }

    func testGuardianPendingReturnLeavesInFlightLoadAlone() async {
        await prepareReturningEarlyLeavesInFlightLoadAlone(guardianLocked: true) {
            if case .guardianPending = $0 { return true } else { return false }
        }
    }

    func testUnresolvedNameReturnLeavesInFlightLoadAlone() async {
        await prepareReturningEarlyLeavesInFlightLoadAlone(athleteName: nil) {
            if case .failed = $0 { return true } else { return false }
        }
    }

    func testLinkCreationFailureReturnLeavesInFlightLoadAlone() async {
        await prepareReturningEarlyLeavesInFlightLoadAlone(createFails: true) {
            if case .failed = $0 { return true } else { return false }
        }
    }

    func testParentNameFromLookupIsTrimmedBeforeItReachesTheCoach() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let auth = MockAuthManager()
        let family = Fixture.makeFamilyManager(authManager: auth)
        let photo = MockProfilePhotoService()
        photo.stubbedFullName = "  Athlete Padded \n"
        let vm = makeVM(service: service, authManager: auth, photo: photo, familyManager: family)

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        guard case let .email(message) = result else { return XCTFail("expected .email, got \(result)") }
        XCTAssertEqual(message.subject, "Athlete Padded Recruiting Profile")
    }

    func testSuccessfulCopyShowsCopiedStateThatThenResets() async throws {
        let service = MockPublicProfileManaging()
        service.stubTrackingLink = link()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let (vm, _) = parentSetup(service: service)
        vm.copiedFeedbackDuration = .milliseconds(100)
        await vm.loadTrackingInfo(for: "c1")
        XCTAssertFalse(vm.linkCopied)

        vm.copyTrackingLink()
        XCTAssertTrue(vm.linkCopied)

        try await Task.sleep(for: .milliseconds(600))
        XCTAssertFalse(vm.linkCopied)
    }

    func testRefusedCopyNeverShowsCopiedState() async {
        let service = MockPublicProfileManaging()
        service.stubTrackingLink = link()
        service.stubProfile = makeProfile(userId: Fixture.athleteUserId)
        let (vm, family) = parentSetup(service: service)
        await vm.loadTrackingInfo(for: "c1")
        Fixture.selectSecondAthlete(in: family)

        vm.copyTrackingLink()

        XCTAssertFalse(vm.linkCopied)
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

    func testPlayerNameFromSessionIsTrimmedBeforeItReachesTheCoach() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile()
        let vm = makeVM(service: service, authManager: selfAuth(fullName: "  Owen Padded \n"))

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        guard case let .email(message) = result else { return XCTFail("expected .email, got \(result)") }
        XCTAssertEqual(message.subject, "Owen Padded Recruiting Profile")
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
}
