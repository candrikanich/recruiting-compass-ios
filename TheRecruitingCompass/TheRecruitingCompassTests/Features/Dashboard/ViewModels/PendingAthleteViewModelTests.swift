import Testing
import Foundation
@testable import TheRecruitingCompass

@Suite("PendingAthleteViewModel: a parent's first-run before the athlete joins (web#1540)")
@MainActor
struct PendingAthleteViewModelTests {

  private let november2026 = Date(timeIntervalSince1970: 1_795_000_000)

  private func makeSUT(
    service: MockPendingAthleteService = MockPendingAthleteService(),
    dashboard: MockDashboardService = MockDashboardService()
  ) -> PendingAthleteViewModel {
    PendingAthleteViewModel(service: service, dashboardService: dashboard)
  }

  private func serviceWithRiley() -> MockPendingAthleteService {
    let service = MockPendingAthleteService()
    service.pendingByFamily["family-1"] = PendingAthlete(athleteFirstName: "Riley", graduationYear: 2028)
    service.catalog = [TaskRow.stub(id: "a"), TaskRow.stub(id: "b", grade: 9)]
    return service
  }

  @Test func showsTheAthletesNameStepsAndTheFamilysSchool() async {
    let dashboard = MockDashboardService()
    dashboard.stubbedFirstRunSignals = FirstRunSignals(coachCount: 0, conversationCount: 0, favoriteSchoolName: "State")
    let sut = makeSUT(service: serviceWithRiley(), dashboard: dashboard)

    await sut.load(familyUnitId: "family-1", referenceDate: november2026)

    #expect(sut.isVisible)
    #expect(sut.heading == "Next steps for Riley")
    #expect(sut.note == "Riley will see these, and the school you add, when they join. They complete the steps themselves.")
    #expect(sut.steps.map(\.taskId) == ["a"])
    #expect(sut.favoriteSchoolName == "State")
    #expect(dashboard.requestedFirstRunSignalFamilyUnitIds == ["family-1"])
  }

  @Test func readsTheCatalogForTheStagedGradeOnly() async {
    let service = serviceWithRiley()
    let sut = makeSUT(service: service)

    await sut.load(familyUnitId: "family-1", referenceDate: november2026)

    #expect(service.requestedCatalogGrades == [11])
  }

  @Test func withoutAStagedGraduationYearThereAreNoStepsAndNoCatalogRead() async {
    let service = MockPendingAthleteService()
    service.pendingByFamily["family-1"] = PendingAthlete(athleteFirstName: "Riley", graduationYear: nil)
    let sut = makeSUT(service: service)

    await sut.load(familyUnitId: "family-1", referenceDate: november2026)

    #expect(sut.steps.isEmpty)
    #expect(service.requestedCatalogGrades.isEmpty)
    #expect(!sut.isVisible)
  }

  @Test func nothingStagedMeansNoCard() async {
    let service = MockPendingAthleteService()
    service.pendingByFamily["family-1"] = .some(nil)
    let sut = makeSUT(service: service)

    await sut.load(familyUnitId: "family-1", referenceDate: november2026)

    #expect(!sut.isVisible)
    #expect(service.requestedCatalogGrades.isEmpty)
  }

  @Test func theSchoolAloneIsEnoughForTheCard() async {
    let dashboard = MockDashboardService()
    dashboard.stubbedFirstRunSignals = FirstRunSignals(coachCount: 0, conversationCount: 0, favoriteSchoolName: "State")
    let sut = makeSUT(dashboard: dashboard)

    await sut.load(familyUnitId: "family-1", referenceDate: november2026)

    #expect(sut.isVisible)
    #expect(sut.steps.isEmpty)
  }

  @Test func theCardStaysHiddenUntilTheFirstLoadFinishes() {
    #expect(!makeSUT().isVisible)
  }

  @Test func noFamilyMeansNoRequests() async {
    let service = serviceWithRiley()
    let dashboard = MockDashboardService()
    let sut = makeSUT(service: service, dashboard: dashboard)

    await sut.load(familyUnitId: nil, referenceDate: november2026)

    #expect(service.requestedFamilyIds.isEmpty)
    #expect(dashboard.requestedFirstRunSignalFamilyUnitIds.isEmpty)
    #expect(!sut.isVisible)
  }

  @Test func aFailedStepsReadStillShowsTheSchool() async {
    let service = serviceWithRiley()
    service.pendingError = URLError(.notConnectedToInternet)
    let dashboard = MockDashboardService()
    dashboard.stubbedFirstRunSignals = FirstRunSignals(coachCount: 0, conversationCount: 0, favoriteSchoolName: "State")
    let sut = makeSUT(service: service, dashboard: dashboard)

    await sut.load(familyUnitId: "family-1", referenceDate: november2026)

    #expect(sut.steps.isEmpty)
    #expect(sut.favoriteSchoolName == "State")
    #expect(sut.isVisible)
  }

  @Test func aFailedCatalogReadShowsNoStepsRatherThanAGuess() async {
    let service = serviceWithRiley()
    service.catalogError = URLError(.timedOut)
    let sut = makeSUT(service: service)

    await sut.load(familyUnitId: "family-1", referenceDate: november2026)

    #expect(sut.steps.isEmpty)
    #expect(!sut.isVisible)
  }

  @Test func aFailedSchoolReadStillShowsTheSteps() async {
    let dashboard = MockDashboardService()
    dashboard.shouldThrowFetchFirstRunSignals = true
    let sut = makeSUT(service: serviceWithRiley(), dashboard: dashboard)

    await sut.load(familyUnitId: "family-1", referenceDate: november2026)

    #expect(sut.steps.map(\.taskId) == ["a"])
    #expect(sut.favoriteSchoolName == nil)
    #expect(sut.isVisible)
  }

  @Test func switchingFamilyNeverShowsThePreviousFamilysAthlete() async {
    let service = serviceWithRiley()
    let sut = makeSUT(service: service)
    await sut.load(familyUnitId: "family-1", referenceDate: november2026)
    #expect(sut.athleteFirstName == "Riley")

    service.pendingError = URLError(.notConnectedToInternet)
    await sut.load(familyUnitId: "family-2", referenceDate: november2026)

    #expect(sut.athleteFirstName == nil)
    #expect(sut.steps.isEmpty)
    #expect(!sut.isVisible)
  }

  @Test func theAthleteJoiningClearsTheCard() async {
    let sut = makeSUT(service: serviceWithRiley())
    await sut.load(familyUnitId: "family-1", referenceDate: november2026)
    #expect(sut.isVisible)

    await sut.load(familyUnitId: nil, referenceDate: november2026)

    #expect(!sut.isVisible)
    #expect(sut.steps.isEmpty)
  }

  @Test func aSlowAnswerForThePreviousFamilyDoesNotLandOverTheCurrentOne() async {
    let service = serviceWithRiley()
    service.pendingByFamily["family-2"] = PendingAthlete(athleteFirstName: "Sam", graduationYear: 2028)
    let gate = AsyncGate(blockedEntries: 1)
    service.pendingGate = { _ in await gate.wait() }
    let sut = makeSUT(service: service)

    let stale = Task { await sut.load(familyUnitId: "family-1", referenceDate: november2026) }
    #expect(await gate.untilEntered())
    await sut.load(familyUnitId: "family-2", referenceDate: november2026)
    gate.open()
    await stale.value

    #expect(sut.athleteFirstName == "Sam")
  }

  @Test func theNameFallsBackWhenTheParentStagedNone() async {
    let service = MockPendingAthleteService()
    service.pendingByFamily["family-1"] = PendingAthlete(athleteFirstName: nil, graduationYear: 2028)
    service.catalog = [TaskRow.stub(id: "a")]
    let sut = makeSUT(service: service)

    await sut.load(familyUnitId: "family-1", referenceDate: november2026)

    #expect(sut.heading == "Next steps for your athlete")
    #expect(sut.note.hasPrefix("They will see these"))
  }
}
