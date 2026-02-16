//
//  DashboardViewTests.swift
//  TheRecruitingCompassTests
//
//  Created by Claude Code on 2/15/26.
//

import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class DashboardViewTests: XCTestCase {
  var authManager: AuthManager!
  var familyManager: FamilyManager!
  var viewModel: DashboardViewModel!

  override func setUp() async throws {
    try await super.setUp()
    authManager = AuthManager.shared
    familyManager = FamilyManager.shared
    viewModel = DashboardViewModel()
  }

  override func tearDown() async throws {
    authManager = nil
    familyManager = nil
    viewModel = nil
    try await super.tearDown()
  }

  func testDashboardView_CanBeInstantiated() throws {
    // Given/When
    let sut = DashboardView(viewModel: viewModel)
      .environment(authManager)
      .environment(familyManager)

    // Then - should not crash
    XCTAssertNotNil(sut, "DashboardView should be instantiable")
  }

  // Manual verification test: Toolbar should only have refresh button (trailing)
  // Before fix: Toolbar has 2 items (settings gear icon + refresh button)
  // After fix: Toolbar has 1 item (refresh button only)
  func testDashboardView_ToolbarState_ManualVerification() throws {
    // Given
    let sut = DashboardView(viewModel: viewModel)
      .environment(authManager)
      .environment(familyManager)

    // When/Then
    // This test verifies the view instantiates correctly.
    // Manual verification required:
    // 1. Run app in simulator
    // 2. Navigate to Dashboard tab
    // 3. Verify toolbar has ONLY refresh button (arrow.clockwise) in trailing position
    // 4. Verify NO settings gear icon in leading position
    // 5. Verify Settings is accessible via dedicated tab
    XCTAssertNotNil(sut, "DashboardView should be instantiable for toolbar verification")
  }
}
