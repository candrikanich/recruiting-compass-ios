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
        interactions: MockInteractionsService = MockInteractionsService()
    ) -> SendProfileViewModel {
        SendProfileViewModel(
            service: service, authManager: authManager,
            preferenceService: preference, photoService: photo, interactionsService: interactions
        )
    }

    private func selfAuth(userId: String = "u1", fullName: String = "Owen Andrikanich") -> MockAuthManager {
        let auth = MockAuthManager()
        auth.setMockUser(User(
            id: userId, email: "o@x.com", emailConfirmedAt: nil, phone: nil,
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
        service.stubProfile = makeProfile(userId: "athlete-9")   // not the signed-in user
        let photo = MockProfilePhotoService()
        photo.stubbedFullName = "Athlete Smith"
        // parent is signed in
        let auth = selfAuth(userId: "parent-1", fullName: "Parent Smith")
        let vm = makeVM(service: service, authManager: auth, photo: photo)

        let result = await vm.prepare(for: makeCoach(email: "coach@x.edu"))

        guard case let .email(message) = result else { return XCTFail("expected .email") }
        XCTAssertEqual(photo.lastFullNameUserId, "athlete-9")
        XCTAssertTrue(message.subject.contains("Athlete Smith"), message.subject)
        XCTAssertFalse(message.subject.contains("Parent Smith"), message.subject)
    }

    // MARK: - loadPublishState (button visibility)

    func testLoadPublishStateReflectsPublishedProfile() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(isPublished: true)
        let vm = makeVM(service: service, authManager: selfAuth())

        await vm.loadPublishState()

        XCTAssertTrue(vm.isPublished)
    }

    func testLoadPublishStateFalseWhenUnpublished() async {
        let service = MockPublicProfileManaging()
        service.stubProfile = makeProfile(isPublished: false)
        let vm = makeVM(service: service, authManager: selfAuth())

        await vm.loadPublishState()

        XCTAssertFalse(vm.isPublished)
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
