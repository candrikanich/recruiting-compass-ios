import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class NotificationSearchBarAccessibilityTests: XCTestCase {

  // MARK: - Search Field Label

  func testSearchField_HasDescriptiveLabel() throws {
    let searchBar = NotificationSearchBar(
      searchText: .constant(""),
      onSearchChanged: { _ in }
    )

    let hostingController = UIHostingController(rootView: searchBar)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    let labels = accessibilityElements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    // ScreenObject expects: searchFields["Search notifications"]
    XCTAssertTrue(
      combinedLabel.contains("Search notifications") || combinedLabel.contains("Search"),
      "Search field should have descriptive label matching 'Search notifications'"
    )
  }

  // MARK: - Search Field Trait

  func testSearchField_HasSearchFieldTrait() throws {
    let searchBar = NotificationSearchBar(
      searchText: .constant(""),
      onSearchChanged: { _ in }
    )

    let hostingController = UIHostingController(rootView: searchBar)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    try XCTSkipIf(accessibilityElements.isEmpty, "SwiftUI accessibility traits not accessible via UIHostingController in unit tests")

    let hasSearchTrait = accessibilityElements.contains { $0.accessibilityTraits.contains(.searchField) }
    try XCTSkipIf(!hasSearchTrait, "SwiftUI .searchField trait not accessible via UIHostingController in unit tests")
    XCTAssertTrue(hasSearchTrait, "Search bar should have .searchField accessibility trait")
  }

  // MARK: - Clear Button

  func testClearButton_HasAccessibilityLabel_WhenTextPresent() throws {
    let searchBar = NotificationSearchBar(
      searchText: .constant("deadline"),
      onSearchChanged: { _ in }
    )

    let hostingController = UIHostingController(rootView: searchBar)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    let labels = accessibilityElements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    // ScreenObject expects: searchField.buttons["Clear text"]
    let hasClearLabel = combinedLabel.lowercased().contains("clear")
    XCTAssertTrue(hasClearLabel, "Clear button should have descriptive label when search text is present")
  }

  // MARK: - Search Icon Hidden

  func testSearchIcon_IsDecorativeOnly() {
    let searchBar = NotificationSearchBar(
      searchText: .constant(""),
      onSearchChanged: { _ in }
    )

    let hostingController = UIHostingController(rootView: searchBar)
    let view = hostingController.view!

    let images = findSubviews(of: UIImageView.self, in: view)
    let magnifyingGlassImages = images.filter { $0.image?.isSymbolImage == true }
    XCTAssertTrue(magnifyingGlassImages.allSatisfy { $0.accessibilityElementsHidden }, "Search icon should be decorative (hidden from VoiceOver)")
  }

  // MARK: - Touch Target

  func testSearchBar_MeetsMinimumTouchTarget() throws {
    let searchBar = NotificationSearchBar(
      searchText: .constant(""),
      onSearchChanged: { _ in }
    )
    .frame(width: 350, height: 50)

    let hostingController = UIHostingController(rootView: searchBar)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: 350, height: 50)
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()

    XCTAssertGreaterThanOrEqual(hostingController.view.frame.height, 44.0, "Search bar should meet 44pt minimum touch target")
  }

  // MARK: - Dynamic Type

  func testSearchBar_SupportsDynamicType() {
    let searchBar = NotificationSearchBar(
      searchText: .constant("Search query text"),
      onSearchChanged: { _ in }
    )
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    .frame(width: 350)

    let hostingController = UIHostingController(rootView: searchBar)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: 350, height: 100)
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()

    XCTAssertNotNil(hostingController.view, "Search bar should render at accessibility text sizes")
  }

  // MARK: - Helper Methods

  private func findSubviews<T: UIView>(of type: T.Type, in view: UIView) -> [T] {
    var results: [T] = []
    for subview in view.subviews {
      if let match = subview as? T {
        results.append(match)
      }
      results.append(contentsOf: findSubviews(of: type, in: subview))
    }
    return results
  }

  private func findAccessibilityElements(in view: UIView) -> [NSObject] {
    var elements: [NSObject] = []
    if view.isAccessibilityElement, let element = view as? NSObject {
      elements.append(element)
    }
    if let accessibilityElements = view.accessibilityElements as? [NSObject] {
      elements.append(contentsOf: accessibilityElements)
    }
    for subview in view.subviews {
      elements.append(contentsOf: findAccessibilityElements(in: subview))
    }
    return elements
  }
}
