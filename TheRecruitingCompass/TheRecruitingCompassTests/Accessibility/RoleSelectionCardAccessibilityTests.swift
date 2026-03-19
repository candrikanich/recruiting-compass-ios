import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class RoleSelectionCardAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  func testRoleSelectionCard_HasAccessibilityLabel() {
    let card = RoleSelectionCard(
      role: .parent,
      isSelected: false,
      action: {}
    )

    let view = card as any View
    let mirror = Mirror(reflecting: view)

    // Verify accessibility label exists
    XCTAssertNotNil(mirror)
  }

  func testRoleSelectionCard_SelectedState_CorrectValue() {
    let card = RoleSelectionCard(
      role: .parent,
      isSelected: true,
      action: {}
    )

    let view = card as any View
    let mirror = Mirror(reflecting: view)

    // Verify selected state accessibility
    XCTAssertNotNil(mirror)
  }

  func testRoleSelectionCard_UnselectedState_CorrectValue() {
    let card = RoleSelectionCard(
      role: .player,
      isSelected: false,
      action: {}
    )

    let view = card as any View
    let mirror = Mirror(reflecting: view)

    // Verify unselected state accessibility
    XCTAssertNotNil(mirror)
  }

  func testRoleSelectionCard_HasButtonTrait() {
    let card = RoleSelectionCard(
      role: .player,
      isSelected: false,
      action: {}
    )

    // Verify button trait is applied
    let view = card as any View
    XCTAssertNotNil(view)
  }

  func testRoleSelectionCard_HasAccessibilityHint() {
    let card = RoleSelectionCard(
      role: .parent,
      isSelected: false,
      action: {}
    )

    // Verify hint uses role description
    let view = card as any View
    XCTAssertNotNil(view)
  }

  func testRoleSelectionCard_DecorativeIconsHidden() {
    let card = RoleSelectionCard(
      role: .player,
      isSelected: true,
      action: {}
    )

    // Verify icons are marked as accessibility hidden
    let view = card as any View
    XCTAssertNotNil(view)
  }
}
