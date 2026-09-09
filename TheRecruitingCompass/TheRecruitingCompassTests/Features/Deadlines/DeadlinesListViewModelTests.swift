import XCTest
@testable import TheRecruitingCompass

@MainActor
final class DeadlinesListViewModelTests: XCTestCase {
  nonisolated deinit {}

  private static let userId = "user-1"
  private static let familyUnitId = "family-1"

  private func makeVM(
    seed: [Deadline] = [],
    playerDetails: PlayerDetails? = nil
  ) -> (DeadlinesListViewModel, MockDeadlinesService, MockPreferenceService) {
    let mockAuth = MockAuthManager()
    mockAuth.setMockUser(User(
      id: Self.userId, email: "athlete@example.com", emailConfirmedAt: nil, phone: nil,
      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z", role: .player
    ))
    let familyManager = FamilyManager(familyService: MockFamilyService(), authManager: mockAuth)
    familyManager.currentMember = FamilyMember(
      id: "member-1", userId: Self.userId, familyUnitId: Self.familyUnitId,
      role: "player", addedAt: nil, user: nil
    )
    familyManager.familyMembers = [familyManager.currentMember!]

    let mockService = MockDeadlinesService()
    mockService.deadlines = seed
    let mockPreferences = MockPreferenceService()
    mockPreferences.stubbedPlayerDetails = playerDetails

    let vm = DeadlinesListViewModel(
      service: mockService, familyManager: familyManager, authManager: mockAuth,
      preferenceService: mockPreferences
    )
    return (vm, mockService, mockPreferences)
  }

  private func deadline(_ id: String, _ date: String, label: String = "Test deadline",
                        category: DeadlineCategory = .application) -> Deadline {
    Deadline(id: id, userId: Self.userId, familyUnitId: Self.familyUnitId, label: label,
             deadlineDate: date, category: category, schoolId: nil, createdAt: nil, updatedAt: nil)
  }

  private func makeSchool(_ id: String, _ name: String) -> School {
    School(
      id: id, userId: Self.userId, name: name, location: nil, city: nil, state: nil,
      division: "D1", conference: nil, ranking: nil, isFavorite: false, website: nil,
      faviconUrl: nil, twitterHandle: nil, instagramHandle: nil, ncaaId: nil, status: "active",
      statusChangedAt: nil, notes: nil, pros: [], cons: [], offerDetails: nil, academicInfo: nil,
      amenities: nil, coachingPhilosophy: nil, coachingStyle: nil, recruitingApproach: nil,
      communicationStyle: nil, successMetrics: nil, familyUnitId: Self.familyUnitId,
      createdBy: nil, updatedBy: nil, createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  func test_loadDeadlines_populatesUserDeadlines() async {
    let (vm, _, _) = makeVM(seed: [deadline("a", "2026-12-01")])
    await vm.loadDeadlines()
    XCTAssertEqual(vm.deadlines.count, 1)
    XCTAssertFalse(vm.isLoading)
  }

  func test_loadDeadlines_mergesSystemMilestonesFromPlayerPreferences() async {
    let details = PlayerDetails()
    var mutable = details
    mutable.primarySport = "Baseball"
    mutable.gender = "male"
    mutable.graduationYear = 2028
    let (vm, _, _) = makeVM(playerDetails: mutable)
    await vm.loadDeadlines()
    // Baseball has a published NCAA calendar with milestones — expect at least one.
    XCTAssertFalse(vm.milestones.isEmpty, "Expected NCAA milestones to load from player preferences")
  }

  func test_loadDeadlines_setsErrorOnFetchFailure() async {
    let (vm, mockService, _) = makeVM()
    mockService.fetchError = NSError(domain: "test", code: 1)
    await vm.loadDeadlines()
    XCTAssertNotNil(vm.errorMessage)
  }

  func test_addDeadline_appendsAndReturnsTrue() async {
    let (vm, _, _) = makeVM()
    await vm.loadDeadlines()
    let ok = await vm.addDeadline(label: "FAFSA due", date: Date(timeIntervalSince1970: 1_893_456_000), category: .financial_aid)
    XCTAssertTrue(ok)
    XCTAssertEqual(vm.deadlines.count, 1)
    XCTAssertEqual(vm.deadlines.first?.label, "FAFSA due")
  }

  func test_addDeadline_passesSchoolId() async {
    let (vm, _, _) = makeVM()
    await vm.loadDeadlines()
    let ok = await vm.addDeadline(
      label: "Official visit", date: .now, category: .visit, schoolId: "school-1"
    )
    XCTAssertTrue(ok)
    XCTAssertEqual(vm.deadlines.first?.schoolId, "school-1")
  }

  func test_addDeadline_defaultsSchoolIdToNil() async {
    let (vm, _, _) = makeVM()
    await vm.loadDeadlines()
    let ok = await vm.addDeadline(label: "FAFSA due", date: .now, category: .financial_aid)
    XCTAssertTrue(ok)
    XCTAssertNil(vm.deadlines.first?.schoolId)
  }

  func test_loadSchools_populatesSchoolsFromService() async {
    let (vm, mockService, _) = makeVM()
    mockService.schools = [makeSchool("school-1", "Test University")]
    await vm.loadSchools()
    XCTAssertEqual(vm.schools.count, 1)
    XCTAssertEqual(vm.schools.first?.name, "Test University")
    XCTAssertFalse(vm.isLoadingSchools)
  }

  func test_addDeadline_rejectsBlankLabel() async {
    let (vm, _, _) = makeVM()
    let ok = await vm.addDeadline(label: "   ", date: .now, category: .custom)
    XCTAssertFalse(ok)
    XCTAssertTrue(vm.deadlines.isEmpty)
  }

  func test_removeDeadline_removesFromList() async {
    let seeded = deadline("a", "2026-12-01")
    let (vm, _, _) = makeVM(seed: [seeded])
    await vm.loadDeadlines()
    XCTAssertEqual(vm.deadlines.count, 1)
    await vm.removeDeadline(seeded)
    XCTAssertTrue(vm.deadlines.isEmpty)
  }

  func test_updateDeadline_editsInPlaceAndReturnsTrue() async {
    let seeded = deadline("a", "2026-12-01", label: "Old label")
    let (vm, _, _) = makeVM(seed: [seeded])
    await vm.loadDeadlines()
    let ok = await vm.updateDeadline(
      id: "a", label: "New label", date: Date(timeIntervalSince1970: 1_893_456_000), category: .visit
    )
    XCTAssertTrue(ok)
    XCTAssertEqual(vm.deadlines.count, 1)
    XCTAssertEqual(vm.deadlines.first?.label, "New label")
    XCTAssertEqual(vm.deadlines.first?.category, .visit)
  }

  func test_updateDeadline_rejectsBlankLabel() async {
    let seeded = deadline("a", "2026-12-01", label: "Old label")
    let (vm, _, _) = makeVM(seed: [seeded])
    await vm.loadDeadlines()
    let ok = await vm.updateDeadline(id: "a", label: "   ", date: .now, category: .custom)
    XCTAssertFalse(ok)
    XCTAssertEqual(vm.deadlines.first?.label, "Old label")
  }

  func test_updateDeadline_setsErrorOnFailure() async {
    let seeded = deadline("a", "2026-12-01")
    let (vm, mockService, _) = makeVM(seed: [seeded])
    await vm.loadDeadlines()
    mockService.updateError = NSError(domain: "test", code: 1)
    let ok = await vm.updateDeadline(id: "a", label: "New label", date: .now, category: .visit)
    XCTAssertFalse(ok)
    XCTAssertNotNil(vm.errorMessage)
  }

  func test_selectedCategory_narrowsGroupedResults() async {
    let (vm, _, _) = makeVM(seed: [
      deadline("a", "2026-12-01", label: "App due", category: .application),
      deadline("b", "2026-12-02", label: "Visit", category: .visit)
    ])
    await vm.loadDeadlines()
    vm.selectedCategory = .visit
    XCTAssertEqual(vm.filteredDeadlines.count, 1)
    XCTAssertEqual(vm.filteredDeadlines.first?.label, "Visit")
  }

  func test_searchText_narrowsGroupedResults() async {
    // Generic NCAA milestones (SAT/FAFSA/etc.) always merge in regardless of
    // sport (RecruitingCalendar.upcomingMilestones), so isolate to user-
    // sourced rows via userDeadline rather than asserting on the raw list.
    let (vm, _, _) = makeVM(seed: [
      deadline("a", "2026-12-01", label: "Uniquelabel due"),
      deadline("b", "2026-12-02", label: "Visit school")
    ])
    await vm.loadDeadlines()
    vm.searchText = "uniquelabel"
    XCTAssertEqual(vm.filteredDeadlines.compactMap(\.userDeadline?.label), ["Uniquelabel due"])
  }

  func test_clearingFilters_restoresAllResults() async {
    let (vm, _, _) = makeVM(seed: [
      deadline("a", "2026-12-01", label: "Uniquelabel due"),
      deadline("b", "2026-12-02", label: "Visit school", category: .visit)
    ])
    await vm.loadDeadlines()
    vm.selectedCategory = .visit
    vm.searchText = "uniquelabel"
    XCTAssertTrue(vm.filteredDeadlines.compactMap(\.userDeadline).isEmpty)
    vm.selectedCategory = nil
    vm.searchText = ""
    XCTAssertEqual(vm.filteredDeadlines.compactMap(\.userDeadline).count, 2)
  }

  func test_upcomingAndPastSplitAroundToday() async {
    let today = DateFormatter.isoDayFormatterForTests.string(from: .now)
    let yesterday = DateFormatter.isoDayFormatterForTests.string(from: Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
    let tomorrow = DateFormatter.isoDayFormatterForTests.string(from: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
    let (vm, _, _) = makeVM(seed: [
      deadline("past", yesterday, label: "Past"),
      deadline("today", today, label: "Today"),
      deadline("future", tomorrow, label: "Future")
    ])
    await vm.loadDeadlines()
    XCTAssertTrue(vm.upcomingDeadlines.contains { $0.label == "Today" })
    XCTAssertTrue(vm.upcomingDeadlines.contains { $0.label == "Future" })
    XCTAssertTrue(vm.pastDeadlines.contains { $0.label == "Past" })
    XCTAssertFalse(vm.pastDeadlines.contains { $0.label == "Today" })
  }
}

private extension DateFormatter {
  static let isoDayFormatterForTests: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.calendar = Calendar(identifier: .gregorian)
    f.timeZone = TimeZone.current
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
  }()
}
