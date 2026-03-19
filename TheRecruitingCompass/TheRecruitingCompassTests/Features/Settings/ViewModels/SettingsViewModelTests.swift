import XCTest
@testable import TheRecruitingCompass

// Per-category mock so we can return different types per category
final class MockPerCategoryPreferenceManager: PreferenceManaging, @unchecked Sendable {
  var results: [PreferenceCategory: Any?] = [:]
  var shouldThrow = false

  func fetchPreferences<T: Codable>(category: PreferenceCategory) async throws -> T? {
    if shouldThrow { throw NSError(domain: "Test", code: 0) }
    return results[category] as? T
  }

  func savePreferences<T: Codable>(category: PreferenceCategory, data: T) async throws -> T {
    return data
  }

  func deletePreferences(category: PreferenceCategory) async throws {}
}

@MainActor
final class SettingsViewModelTests: XCTestCase {
  nonisolated deinit {}
  var viewModel: SettingsViewModel!
  var mockService: MockPerCategoryPreferenceManager!

  override func setUp() async throws {
    try await super.setUp()
    mockService = MockPerCategoryPreferenceManager()
    viewModel = SettingsViewModel(preferenceService: mockService)
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
    super.tearDown()
  }

  // MARK: - Initial state

  func testInitialState_StatusesAreNil() {
    XCTAssertNil(viewModel.homeLocationStatus)
    XCTAssertNil(viewModel.playerDetailsStatus)
    XCTAssertNil(viewModel.schoolPreferencesStatus)
  }

  // MARK: - Home Location

  func testHomeLocationStatus_WithCoordinates_IsComplete() async {
    mockService.results[.location] = HomeLocation(
      address: nil, city: "Austin", state: "TX", zip: nil,
      latitude: 30.27, longitude: -97.74
    )
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.homeLocationStatus, .complete)
  }

  func testHomeLocationStatus_WithoutCoordinates_IsIncomplete() async {
    mockService.results[.location] = HomeLocation(
      address: nil, city: "Austin", state: "TX", zip: nil,
      latitude: nil, longitude: nil
    )
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.homeLocationStatus, .incomplete)
  }

  func testHomeLocationStatus_NoData_IsIncomplete() async {
    // fetchPreferences returns nil (no data saved)
    mockService.results[.location] = Optional<HomeLocation>.none
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.homeLocationStatus, .incomplete)
  }

  // MARK: - Player Details

  func testPlayerDetailsStatus_WithGraduationYear_IsComplete() async {
    var details = PlayerDetails()
    details.graduationYear = 2027
    mockService.results[.player] = details
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.playerDetailsStatus, .complete)
  }

  func testPlayerDetailsStatus_WithPositions_IsComplete() async {
    var details = PlayerDetails()
    details.positions = ["Pitcher", "Outfield"]
    mockService.results[.player] = details
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.playerDetailsStatus, .complete)
  }

  func testPlayerDetailsStatus_EmptyDetails_IsIncomplete() async {
    mockService.results[.player] = PlayerDetails()
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.playerDetailsStatus, .incomplete)
  }

  func testPlayerDetailsStatus_NoData_IsIncomplete() async {
    mockService.results[.player] = Optional<PlayerDetails>.none
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.playerDetailsStatus, .incomplete)
  }

  // MARK: - School Preferences

  func testSchoolPreferencesStatus_WithPreferences_IsComplete() async {
    let prefs = SchoolPreferences(
      preferences: [
        SchoolPreference(id: "1", category: .location, type: "max_distance_miles",
                         value: .int(500), priority: 1, isDealbreaker: false)
      ],
      templateUsed: nil, lastUpdated: nil
    )
    mockService.results[.school] = prefs
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.schoolPreferencesStatus, .complete)
  }

  func testSchoolPreferencesStatus_EmptyPreferences_IsIncomplete() async {
    mockService.results[.school] = SchoolPreferences(preferences: [], templateUsed: nil, lastUpdated: nil)
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.schoolPreferencesStatus, .incomplete)
  }

  func testSchoolPreferencesStatus_NoData_IsIncomplete() async {
    mockService.results[.school] = Optional<SchoolPreferences>.none
    await viewModel.loadCompletionStatus()
    XCTAssertEqual(viewModel.schoolPreferencesStatus, .incomplete)
  }

  // MARK: - Error handling

  func testLoadCompletionStatus_OnError_StatusesRemainNil() async {
    // When service throws, statuses stay nil (badges just won't show)
    mockService.shouldThrow = true
    await viewModel.loadCompletionStatus()
    XCTAssertNil(viewModel.homeLocationStatus)
    XCTAssertNil(viewModel.playerDetailsStatus)
    XCTAssertNil(viewModel.schoolPreferencesStatus)
  }

  // MARK: - Parallel loading

  func testLoadCompletionStatus_AllThreeLoaded_AllStatusesSet() async {
    var details = PlayerDetails()
    details.graduationYear = 2028
    mockService.results[.location] = HomeLocation(
      address: nil, city: nil, state: nil, zip: nil,
      latitude: 30.27, longitude: -97.74
    )
    mockService.results[.player] = details
    mockService.results[.school] = SchoolPreferences(preferences: [], templateUsed: nil, lastUpdated: nil)

    await viewModel.loadCompletionStatus()

    XCTAssertEqual(viewModel.homeLocationStatus, .complete)
    XCTAssertEqual(viewModel.playerDetailsStatus, .complete)
    XCTAssertEqual(viewModel.schoolPreferencesStatus, .incomplete)
  }
}
