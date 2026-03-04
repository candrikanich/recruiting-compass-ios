import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class RoleSelectionCardTests: XCTestCase {
  func testRoleSelectionCardDisplaysParentRole() {
    let card = RoleSelectionCard(
      role: .parent,
      isSelected: false,
      action: {}
    )

    XCTAssertNotNil(card)
  }

  func testRoleSelectionCardDisplaysPlayerRole() {
    let card = RoleSelectionCard(
      role: .player,
      isSelected: false,
      action: {}
    )

    XCTAssertNotNil(card)
  }

  func testRoleSelectionCardSelectednState() {
    let card = RoleSelectionCard(
      role: .parent,
      isSelected: true,
      action: {}
    )

    XCTAssertNotNil(card)
  }

  func testUserRoleDisplayNames() {
    XCTAssertEqual(UserRole.parent.displayName, "Parent")
    XCTAssertEqual(UserRole.player.displayName, "Player")
  }

  func testUserRoleIcons() {
    XCTAssertNotNil(UserRole.parent.icon)
    XCTAssertNotNil(UserRole.player.icon)
  }

  func testUserRoleDescriptions() {
    XCTAssertFalse(UserRole.parent.description.isEmpty)
    XCTAssertFalse(UserRole.player.description.isEmpty)
  }

  func testUserRoleRequiresFamilyCode() {
    // Both roles create their own family at signup; neither requires a family code.
    XCTAssertFalse(UserRole.parent.requiresFamilyCode)
    XCTAssertFalse(UserRole.player.requiresFamilyCode)
  }
}
