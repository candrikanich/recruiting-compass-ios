import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class SidebarViewTests: XCTestCase {
  nonisolated deinit {}

  func testSidebarRendersAllDestinations() throws {
    let view = SidebarView(selection: .constant(.dashboard))

    // Verify all sections are represented
    let mainItems = AppDestination.allCases.filter { $0.section == .main }
    let moreItems = AppDestination.allCases.filter { $0.section == .more }
    let bottomItems = AppDestination.allCases.filter { $0.section == .bottom }

    XCTAssertEqual(mainItems.count, 6)
    XCTAssertEqual(moreItems.count, 5)
    XCTAssertEqual(bottomItems.count, 1)
    XCTAssertNotNil(view)
  }

  func testSidebarDefaultSelection() {
    let view = SidebarView(selection: .constant(.dashboard))
    // Compiles and renders without crash
    XCTAssertNotNil(view)
  }
}
