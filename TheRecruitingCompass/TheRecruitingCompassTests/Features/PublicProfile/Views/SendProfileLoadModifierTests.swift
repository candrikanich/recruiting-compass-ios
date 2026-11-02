import SwiftUI
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SendProfileLoadModifierTests: XCTestCase {
    nonisolated deinit {}

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    func testChangingTheSelectedAthleteReloadsTrackingInfo() async {
        let service = MockPublicProfileManaging()
        let auth = MockAuthManager()
        let family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
        let vm = SendProfileViewModel(
            service: service, authManager: auth, preferenceService: MockPreferenceService(),
            photoService: MockProfilePhotoService(), interactionsService: MockInteractionsService(),
            familyManager: family
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = UIHostingController(
            rootView: Color.clear.modifier(SendProfileLoadModifier(viewModel: vm, coachId: "c1"))
        )
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        await waitUntil { service.fetchedAthleteIds.count == 1 }
        XCTAssertEqual(service.fetchedAthleteIds, [ParentViewingAthleteFixture.athleteUserId])

        ParentViewingAthleteFixture.selectSecondAthlete(in: family)
        await waitUntil { service.fetchedAthleteIds.count == 2 }

        XCTAssertEqual(
            service.fetchedAthleteIds,
            [ParentViewingAthleteFixture.athleteUserId, ParentViewingAthleteFixture.secondAthleteUserId]
        )
    }
}
