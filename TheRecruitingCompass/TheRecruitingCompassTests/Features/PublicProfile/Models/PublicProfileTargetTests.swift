import XCTest

@testable import TheRecruitingCompass

final class PublicProfileTargetTests: XCTestCase {
    private func user(id: String, role: UserRole?) -> User {
        User(id: id, email: "x@example.com", emailConfirmedAt: nil, fullName: "X",
             createdAt: "", updatedAt: "", role: role, dateOfBirth: nil)
    }

    func testParentWithSelectedAthleteTargetsTheAthlete() {
        let target = PublicProfileTarget.userId(
            user: user(id: "parent-1", role: .parent), selectedAthleteUserId: "athlete-A")
        XCTAssertEqual(target, "athlete-A")
    }

    func testParentWithoutSelectedAthleteHasNoTarget() {
        let target = PublicProfileTarget.userId(
            user: user(id: "parent-1", role: .parent), selectedAthleteUserId: nil)
        XCTAssertNil(target)
    }

    func testPlayerTargetsOwnIdEvenIfAnAthleteIsSelected() {
        let target = PublicProfileTarget.userId(
            user: user(id: "player-1", role: .player), selectedAthleteUserId: "athlete-A")
        XCTAssertEqual(target, "player-1")
    }

    func testPlayerWithoutSelectionTargetsOwnId() {
        let target = PublicProfileTarget.userId(
            user: user(id: "player-1", role: .player), selectedAthleteUserId: nil)
        XCTAssertEqual(target, "player-1")
    }

    func testSignedOutHasNoTarget() {
        XCTAssertNil(PublicProfileTarget.userId(user: nil, selectedAthleteUserId: "athlete-A"))
    }
}
