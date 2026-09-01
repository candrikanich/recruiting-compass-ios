import Testing
import Foundation
@testable import TheRecruitingCompass

@Suite("NuxProgressManager — optimistic-update behavior")
@MainActor
struct NuxProgressManagerTests {

  private func makeSUT(
    service: MockNuxProgressService = MockNuxProgressService()
  ) -> (NuxProgressManager, MockNuxProgressService) {
    let manager = NuxProgressManager(service: service)
    return (manager, service)
  }

  // MARK: - load

  @Test func loadSetsProgressFromService() async {
    let mockService = MockNuxProgressService()
    var stubbedProgress = NuxProgress.empty
    stubbedProgress.completeItem(.sport)
    mockService.stubbedProgress = stubbedProgress

    let (sut, _) = makeSUT(service: mockService)
    await sut.load(userId: "user-1")

    #expect(sut.isLoaded)
    #expect(sut.progress.isItemCompleted(.sport))
  }

  @Test func loadFallsBackToEmptyOnError() async {
    let mockService = MockNuxProgressService()
    mockService.shouldThrowOnFetch = true

    let (sut, _) = makeSUT(service: mockService)
    await sut.load(userId: "user-1")

    #expect(sut.isLoaded)
    #expect(sut.progress.checklist.completedCount == 0)
  }

  // MARK: - completeItem

  @Test func completeItemUpdatesProgressOptimistically() {
    let (sut, _) = makeSUT()
    sut.completeItem(.firstSchool)

    #expect(sut.progress.isItemCompleted(.firstSchool))
  }

  @Test func completeItemIsIdempotent() {
    let (sut, _) = makeSUT()
    sut.completeItem(.firstSchool)
    let firstCount = sut.progress.checklist.completedCount

    sut.completeItem(.firstSchool)
    #expect(sut.progress.checklist.completedCount == firstCount)
  }

  @Test func completeItemDoesNotCompleteAlreadyCompletedItem() {
    let (sut, _) = makeSUT()
    sut.completeItem(.sport)
    let timestamp = sut.progress.checklist.items[NuxChecklistKey.sport.rawValue]?.completedAt

    sut.completeItem(.sport)
    let secondTimestamp = sut.progress.checklist.items[NuxChecklistKey.sport.rawValue]?.completedAt
    #expect(timestamp == secondTimestamp)
  }

  // MARK: - dismissChecklist

  @Test func dismissChecklistSetsDismissedAt() {
    let (sut, _) = makeSUT()
    #expect(sut.progress.checklist.dismissedAt == nil)

    sut.dismissChecklist()

    #expect(sut.progress.checklist.dismissedAt != nil)
  }

  // MARK: - resumeChecklist

  @Test func resumeChecklistClearsDismissedAt() {
    let (sut, _) = makeSUT()
    sut.dismissChecklist()
    #expect(sut.progress.checklist.dismissedAt != nil)

    sut.resumeChecklist()

    #expect(sut.progress.checklist.dismissedAt == nil)
  }

  // MARK: - dismissPrompt

  @Test func dismissPromptRecordsDismissal() {
    let (sut, _) = makeSUT()
    sut.dismissPrompt("invite_nag")

    #expect(sut.progress.dismissals["invite_nag"] != nil)
    #expect(sut.progress.isPromptDismissed("invite_nag", cooldownDays: 7))
  }

  // MARK: - recordFirstVisit

  @Test func recordFirstVisitSavesTimestamp() {
    let (sut, _) = makeSUT()
    sut.recordFirstVisit("dashboard")

    #expect(sut.progress.firstVisits["dashboard"] != nil)
  }

  @Test func recordFirstVisitDoesNotOverwriteExisting() {
    let (sut, _) = makeSUT()
    sut.recordFirstVisit("dashboard")
    let firstTimestamp = sut.progress.firstVisits["dashboard"]

    sut.recordFirstVisit("dashboard")
    let secondTimestamp = sut.progress.firstVisits["dashboard"]

    #expect(firstTimestamp == secondTimestamp)
  }

  // MARK: - persistInBackground (indirect verification)

  @Test func completeItemTriggersPersist() async throws {
    let mockService = MockNuxProgressService()
    let (sut, _) = makeSUT(service: mockService)
    await sut.load(userId: "user-1")

    sut.completeItem(.sport)

    // Allow background Task to run
    try await Task.sleep(for: .milliseconds(100))

    #expect(mockService.saveCallCount >= 1)
    #expect(mockService.lastSavedUserId == "user-1")
    #expect(mockService.lastSavedProgress?.isItemCompleted(.sport) == true)
  }

  @Test func noUserIdSkipsPersist() async throws {
    let mockService = MockNuxProgressService()
    let (sut, _) = makeSUT(service: mockService)
    // Don't call load (no userId set)
    sut.completeItem(.sport)

    try await Task.sleep(for: .milliseconds(100))

    #expect(mockService.saveCallCount == 0)
  }
}
