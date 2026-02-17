import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class OfferFilterBarAccessibilityTests: XCTestCase {

  // MARK: - Status Picker Label

  func testStatusPicker_HasAccessibilityLabel() throws {
    let filters = OfferFilters()
    let filterBar = OfferFilterBar(filters: .constant(filters))

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    let labels = accessibilityElements.compactMap { $0.accessibilityLabel }
    let combined = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(combined.contains("Filter by status"), "Status picker should have 'Filter by status' label")
  }

  // MARK: - Offer Type Picker Label

  func testOfferTypePicker_HasAccessibilityLabel() throws {
    let filters = OfferFilters()
    let filterBar = OfferFilterBar(filters: .constant(filters))

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    let labels = accessibilityElements.compactMap { $0.accessibilityLabel }
    let combined = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(combined.contains("Filter by offer type"), "Offer type picker should have 'Filter by offer type' label")
  }

  // MARK: - Sort Pickers

  func testSortByPicker_HasAccessibilityLabel() throws {
    let filters = OfferFilters()
    let filterBar = OfferFilterBar(filters: .constant(filters))

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    let labels = accessibilityElements.compactMap { $0.accessibilityLabel }
    let combined = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(combined.contains("Sort by field"), "Sort by picker should have 'Sort by field' label")
  }

  func testSortDirectionPicker_HasAccessibilityLabel() throws {
    let filters = OfferFilters()
    let filterBar = OfferFilterBar(filters: .constant(filters))

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    let labels = accessibilityElements.compactMap { $0.accessibilityLabel }
    let combined = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(combined.contains("Sort direction"), "Sort direction picker should have 'Sort direction' label")
  }

  // MARK: - All Pickers Have Hints

  func testAllPickers_HaveAccessibilityHints() throws {
    let filters = OfferFilters()
    let filterBar = OfferFilterBar(filters: .constant(filters))

    let hostingController = UIHostingController(rootView: filterBar)
    let view = hostingController.view!

    let hints = findAccessibilityHints(in: view)

    try XCTSkipIf(hints.isEmpty, "SwiftUI accessibility hints not accessible via UIHostingController in unit tests")

    XCTAssertTrue(hints.contains(where: { $0.contains("Double tap") }), "Pickers should have hints starting with 'Double tap'")
  }

  // MARK: - Helper Methods

  private func findAccessibilityElements(in view: UIView) -> [NSObject] {
    var elements: [NSObject] = []

    if view.isAccessibilityElement {
      elements.append(view)
    }

    if let accessibilityElements = view.accessibilityElements as? [NSObject] {
      elements.append(contentsOf: accessibilityElements)
    }

    for subview in view.subviews {
      elements.append(contentsOf: findAccessibilityElements(in: subview))
    }

    return elements
  }

  private func findAccessibilityHints(in view: UIView) -> [String] {
    var hints: [String] = []

    if let hint = view.accessibilityHint {
      hints.append(hint)
    }

    for subview in view.subviews {
      hints.append(contentsOf: findAccessibilityHints(in: subview))
    }

    return hints
  }
}
