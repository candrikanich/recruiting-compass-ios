//
//  MainTabViewTests.swift
//  TheRecruitingCompassTests
//
//  Created by Claude Code on 2/15/26.
//

import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class MainTabViewTests: XCTestCase {
  var authManager: AuthManager!
  var familyManager: FamilyManager!

  override func setUp() async throws {
    try await super.setUp()
    authManager = AuthManager.shared
    familyManager = FamilyManager.shared
  }

  override func tearDown() async throws {
    authManager = nil
    familyManager = nil
    try await super.tearDown()
  }

  func testMainTabView_CanBeInstantiated() throws {
    // Given/When
    let sut = MainTabView()
      .environmentObject(authManager)
      .environmentObject(familyManager)

    // Then - should not crash
    XCTAssertNotNil(sut, "MainTabView should be instantiable")
  }
}
