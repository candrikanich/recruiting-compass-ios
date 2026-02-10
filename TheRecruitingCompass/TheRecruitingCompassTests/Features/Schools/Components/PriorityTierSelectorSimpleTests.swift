import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class PriorityTierSelectorSimpleTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInitialization_WithNilTier() {
    let selector = PriorityTierSelector(
      selectedTier: nil,
      isUpdating: false,
      onSelect: { _ in }
    )

    XCTAssertNil(selector.selectedTier)
  }

  func testInitialization_WithTierA() {
    let selector = PriorityTierSelector(
      selectedTier: .a,
      isUpdating: false,
      onSelect: { _ in }
    )

    XCTAssertEqual(selector.selectedTier, .a)
  }

  func testInitialization_IsNotUpdating() {
    let selector = PriorityTierSelector(
      selectedTier: nil,
      isUpdating: false,
      onSelect: { _ in }
    )

    XCTAssertFalse(selector.isUpdating)
  }

  func testInitialization_IsUpdating() {
    let selector = PriorityTierSelector(
      selectedTier: .a,
      isUpdating: true,
      onSelect: { _ in }
    )

    XCTAssertTrue(selector.isUpdating)
  }

  // MARK: - Selection Callback Tests

  func testOnSelect_CallsCallback() async {
    var callbackCalled = false
    var selectedValue: PriorityTier?

    let selector = PriorityTierSelector(
      selectedTier: nil,
      isUpdating: false,
      onSelect: { tier in
        callbackCalled = true
        selectedValue = tier
      }
    )

    await selector.onSelect(.a)

    XCTAssertTrue(callbackCalled)
    XCTAssertEqual(selectedValue, .a)
  }

  func testOnSelect_WithNil_CallsCallback() async {
    var callbackCalled = false
    var selectedValue: PriorityTier? = .a

    let selector = PriorityTierSelector(
      selectedTier: .a,
      isUpdating: false,
      onSelect: { tier in
        callbackCalled = true
        selectedValue = tier
      }
    )

    await selector.onSelect(nil)

    XCTAssertTrue(callbackCalled)
    XCTAssertNil(selectedValue)
  }
}
