import XCTest
@testable import TheRecruitingCompass

/// Verifies Events List accessibility labels and display names per spec §6 Accessibility.
@MainActor
final class EventsListAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Calendar Labels

  func testCalendarTitle_includesMonthAndYear() {
    let vm = EventsListViewModel(
      eventsService: MockEventsService(),
      authManager: MockAuthManager()
    )
    XCTAssertTrue(vm.currentMonthTitle.contains(String(Calendar.current.component(.year, from: Date()))))
    XCTAssertFalse(vm.currentMonthTitle.isEmpty)
  }

  // MARK: - Event Type Display Names (used in accessibility labels)

  func testEventType_camp_hasCorrectDisplayName() {
    XCTAssertEqual(EventType.camp.displayName, "Camp")
  }

  func testEventType_showcase_hasCorrectDisplayName() {
    XCTAssertEqual(EventType.showcase.displayName, "Showcase")
  }

  func testEventType_officialVisit_hasCorrectDisplayName() {
    XCTAssertEqual(EventType.officialVisit.displayName, "Official Visit")
  }

  func testEventType_unofficialVisit_hasCorrectDisplayName() {
    XCTAssertEqual(EventType.unofficialVisit.displayName, "Unofficial Visit")
  }

  func testEventType_game_hasCorrectDisplayName() {
    XCTAssertEqual(EventType.game.displayName, "Game")
  }

  // MARK: - Status Filter Display Names (used in picker accessibility)

  func testStatusFilter_all_rawValueIsHumanReadable() {
    XCTAssertEqual(StatusFilter.all.rawValue, "All")
  }

  func testStatusFilter_attended_rawValueIsHumanReadable() {
    XCTAssertEqual(StatusFilter.attended.rawValue, "Attended")
  }

  func testStatusFilter_registered_rawValueIsHumanReadable() {
    XCTAssertEqual(StatusFilter.registered.rawValue, "Registered")
  }

  func testStatusFilter_notRegistered_rawValueIsHumanReadable() {
    XCTAssertEqual(StatusFilter.notRegistered.rawValue, "Not Registered")
  }

  // MARK: - Sort Option Display Names (used in picker accessibility)

  func testSortOption_dateDesc_rawValueIsHumanReadable() {
    XCTAssertEqual(SortOption.dateDesc.rawValue, "Date (Newest First)")
  }

  func testSortOption_dateAsc_rawValueIsHumanReadable() {
    XCTAssertEqual(SortOption.dateAsc.rawValue, "Date (Oldest First)")
  }

  func testSortOption_name_rawValueIsHumanReadable() {
    XCTAssertEqual(SortOption.name.rawValue, "Name")
  }

  func testSortOption_type_rawValueIsHumanReadable() {
    XCTAssertEqual(SortOption.type.rawValue, "Type")
  }

  // MARK: - Date Range Filter Display Names

  func testDateRangeFilter_allCases_haveHumanReadableRawValues() {
    for filter in DateRangeFilter.allCases {
      XCTAssertFalse(filter.rawValue.isEmpty, "\(filter) has empty raw value")
      XCTAssertFalse(filter.rawValue.contains("_"), "\(filter).rawValue '\(filter.rawValue)' should be display string")
    }
  }
}
