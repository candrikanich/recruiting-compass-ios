import SwiftUI
import XCTest
@testable import TheRecruitingCompass

/// Renders the real `CoachDetailView` (services mocked) so a regression that stops it loading Send Profile state
/// for its own coach - modifier removed, commented out, in a branch that never renders, or ignoring the coach
/// id - fails here rather than only in a manual pass.
@MainActor
final class CoachDetailSendProfileRenderTests: XCTestCase {
    nonisolated deinit {}

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    func testRenderedCoachScreenLoadsSendProfileStateForItsOwnCoach() async {
        let auth = MockAuthManager()
        auth.setMockUser(User(
            id: "u1", email: "o@x.com", emailConfirmedAt: nil, fullName: "Owen Andrikanich",
            createdAt: "", updatedAt: "", role: nil, dateOfBirth: nil
        ))
        let service = MockPublicProfileManaging()
        service.stubProfile = PlayerProfile(
            id: "p1", userId: "u1", familyUnitId: "f1", hashSlug: "ab", vanitySlug: "owen", isPublished: true,
            bio: nil, headerColor: "slate", showAcademics: true, showAthletic: true, showFilm: true,
            showSchools: true, createdAt: "", updatedAt: ""
        )
        let coach = Coach(
            id: "coach-render-1", firstName: "Jane", lastName: "Smith", email: "c@x.edu", phone: nil,
            schoolId: "s1", createdAt: "", updatedAt: ""
        )
        let sendVM = SendProfileViewModel(
            service: service, authManager: auth, preferenceService: MockPreferenceService(),
            photoService: MockProfilePhotoService(), interactionsService: MockInteractionsService(),
            familyManager: FamilyManager(familyService: MockFamilyService(), authManager: auth)
        )
        let detailVM = CoachDetailViewModel(
            coachId: coach.id, allCoaches: [coach], allSchools: [],
            coachesService: MockCoachesService(), interactionsService: MockInteractionsService(),
            authManager: auth, cache: InMemoryCache()
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(rootView: NavigationStack {
            CoachDetailView(
                coachId: coach.id, allCoaches: [coach], viewModel: detailVM, sendProfileViewModel: sendVM
            )
        })
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        await waitUntil { !service.fetchedTrackingCoachIds.isEmpty }

        XCTAssertEqual(service.fetchedTrackingCoachIds, [coach.id])
    }
}
