import Foundation
import Testing
@testable import TheRecruitingCompass

/// Holds an async call until `open()` so a test can interleave work with an in-flight load.
@MainActor
private final class AsyncGate {
  nonisolated deinit {}

  private(set) var enteredCount = 0
  private var isOpen = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func wait() async {
    enteredCount += 1
    guard !isOpen else { return }
    await withCheckedContinuation { waiters.append($0) }
  }

  func open() {
    isOpen = true
    waiters.forEach { $0.resume() }
    waiters = []
  }

  func untilEntered() async {
    while enteredCount == 0 { await Task.yield() }
  }
}

@Suite("FamilyManager — account switching")
@MainActor
struct FamilyManagerTests {

  private func user(_ id: String, role: UserRole) -> User {
    User(
      id: id,
      email: "\(id)@example.com",
      emailConfirmedAt: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: role
    )
  }

  private func member(id: String, userId: String, familyUnitId: String, role: String) -> FamilyMember {
    FamilyMember(
      id: id,
      userId: userId,
      familyUnitId: familyUnitId,
      role: role,
      addedAt: "2024-01-01T00:00:00Z",
      user: nil
    )
  }

  @Test func resetClearsEverythingTiedToThePreviousUser() {
    let sut = FamilyManager(familyService: MockFamilyService(), authManager: MockAuthManager())
    let athlete = member(id: "m-a", userId: "user-a", familyUnitId: "family-a", role: "player")
    sut.currentMember = athlete
    sut.familyMembers = [athlete]
    sut.selectedAthleteId = athlete.id

    sut.reset()

    #expect(sut.currentMember == nil)
    #expect(sut.familyMembers.isEmpty)
    #expect(sut.selectedAthleteId == nil)
    #expect(sut.familyUnit == nil)
    #expect(sut.familyUnitId == nil)
  }

  @Test func parentSwitchingAccountsSelectsTheirOwnAthlete() async {
    let service = MockFamilyService()
    let auth = MockAuthManager()
    let sut = FamilyManager(familyService: service, authManager: auth)
    sut.selectedAthleteId = "m-athlete-from-previous-family"

    auth.setMockUser(user("parent-b", role: .parent))
    sut.reset()
    let parentB = member(id: "m-parent-b", userId: "parent-b", familyUnitId: "family-b", role: "parent")
    let athleteB = member(id: "m-athlete-b", userId: "athlete-b", familyUnitId: "family-b", role: "player")
    service.stubbedCurrentMember = parentB
    service.stubbedFamilyMembers = [parentB, athleteB]
    await sut.loadFamilyData()

    #expect(sut.selectedAthleteId == "m-athlete-b")
  }

  @Test func concurrentLoadWaitsForTheLoadAlreadyInFlight() async {
    let service = MockFamilyService()
    let gate = AsyncGate()
    service.getCurrentMemberGate = { await gate.wait() }
    service.stubbedCurrentMember = member(id: "m-a", userId: "user-a", familyUnitId: "family-a", role: "player")
    let auth = MockAuthManager()
    auth.setMockUser(user("user-a", role: .player))
    let sut = FamilyManager(familyService: service, authManager: auth)

    let first = Task { await sut.loadFamilyData() }
    await gate.untilEntered()
    let second = Task { () -> String? in
      await sut.loadFamilyData()
      return sut.familyUnitId
    }
    for _ in 0..<5 { await Task.yield() }
    gate.open()

    #expect(await second.value == "family-a")
    await first.value
    #expect(service.getCurrentMemberCallCount == 1)
  }

  @Test func loadStartedForPreviousUserIsDiscardedAfterSwitch() async {
    let service = MockFamilyService()
    let gate = AsyncGate()
    service.getCurrentMemberGate = { await gate.wait() }
    service.stubbedCurrentMember = member(id: "m-a", userId: "user-a", familyUnitId: "family-a", role: "player")
    let auth = MockAuthManager()
    auth.setMockUser(user("user-a", role: .player))
    let sut = FamilyManager(familyService: service, authManager: auth)

    let staleLoad = Task { await sut.loadFamilyData() }
    await gate.untilEntered()
    auth.setMockUser(user("user-b", role: .player))
    sut.reset()
    gate.open()
    await staleLoad.value

    #expect(sut.currentMember == nil)
    #expect(sut.familyUnitId == nil)
    #expect(sut.familyMembers.isEmpty)
  }
}
