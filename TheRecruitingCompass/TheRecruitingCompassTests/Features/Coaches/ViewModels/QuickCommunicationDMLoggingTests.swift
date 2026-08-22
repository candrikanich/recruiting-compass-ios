import XCTest
@testable import TheRecruitingCompass

@MainActor
final class QuickCommunicationDMLoggingTests: XCTestCase {
    nonisolated deinit {}

    private func coach() -> Coach {
        Coach(id: "c1", firstName: "Sam", lastName: "Smith", email: "s@x.com", phone: "555",
              position: "HC", schoolId: "s1", createdAt: "", updatedAt: "")
    }

    func test_logInstagramDM_createsOutboundDMInteraction() async {
        let interactions = MockInteractionsService()
        let vm = QuickCommunicationViewModel(
            coach: coach(),
            interactionsService: interactions,
            coachesService: MockCoachesService(),
            loggedBy: "u1",
            familyUnitId: "f1"
        )

        await vm.logInstagramDM()

        XCTAssertEqual(interactions.createInteractionCallCount, 1)
        XCTAssertEqual(interactions.lastCreatedInteractionRequest?.type, "dm")
        XCTAssertEqual(interactions.lastCreatedInteractionRequest?.direction, "outbound")
        XCTAssertEqual(interactions.lastCreatedInteractionRequest?.coachId, "c1")
        XCTAssertEqual(interactions.lastCreatedInteractionRequest?.schoolId, "s1")
    }

    func test_logInstagramDM_missingContext_doesNotCreate() async {
        let interactions = MockInteractionsService()
        let vm = QuickCommunicationViewModel(
            coach: coach(),
            interactionsService: interactions
            // no loggedBy / familyUnitId
        )

        await vm.logInstagramDM()

        XCTAssertEqual(interactions.createInteractionCallCount, 0)
    }
}
