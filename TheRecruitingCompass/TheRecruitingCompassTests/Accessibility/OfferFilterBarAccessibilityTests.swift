import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class OfferFilterBarAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  private func makeFilterBar() -> OfferFilterBar {
    OfferFilterBar(filters: .constant(OfferFilters()))
  }

  // MARK: - Picker Labels

  func testStatusPicker_HasAccessibilityLabel() {
    XCTAssertEqual(makeFilterBar().statusFilterLabel, "Filter by status")
  }

  func testOfferTypePicker_HasAccessibilityLabel() {
    XCTAssertEqual(makeFilterBar().offerTypeFilterLabel, "Filter by offer type")
  }

  func testSortByPicker_HasAccessibilityLabel() {
    XCTAssertEqual(makeFilterBar().sortByFieldLabel, "Sort by field")
  }

  func testSortDirectionPicker_HasAccessibilityLabel() {
    XCTAssertEqual(makeFilterBar().sortDirectionLabel, "Sort direction")
  }

  // MARK: - Picker Hints

  func testAllPickers_HaveAccessibilityHints() {
    let bar = makeFilterBar()
    let hints = [
      bar.statusFilterHint,
      bar.offerTypeFilterHint,
      bar.sortByFieldHint,
      bar.sortDirectionHint
    ]

    XCTAssertTrue(
      hints.allSatisfy { $0.hasPrefix("Double tap") },
      "All picker hints should start with 'Double tap'"
    )
  }
}
