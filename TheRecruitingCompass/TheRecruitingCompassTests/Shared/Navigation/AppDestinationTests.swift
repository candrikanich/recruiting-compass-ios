import XCTest
@testable import TheRecruitingCompass

final class AppDestinationTests: XCTestCase {
  func testAllCasesExist() {
    let allCases = AppDestination.allCases
    XCTAssertEqual(allCases.count, 12)
  }

  func testSectionGrouping() {
    let mainItems = AppDestination.allCases.filter { $0.section == .main }
    let moreItems = AppDestination.allCases.filter { $0.section == .more }
    let bottomItems = AppDestination.allCases.filter { $0.section == .bottom }

    XCTAssertEqual(mainItems.count, 6, "Main: dashboard, schools, coaches, interactions, timeline, events")
    XCTAssertEqual(moreItems.count, 5, "More: performance, offers, analytics, documents, deadlines")
    XCTAssertEqual(bottomItems.count, 1, "Bottom: settings")
  }

  func testMainSectionOrder() {
    let mainItems = AppDestination.allCases.filter { $0.section == .main }
    XCTAssertEqual(mainItems, [.dashboard, .schools, .coaches, .interactions, .timeline, .events])
  }

  func testEachCaseHasLabel() {
    for destination in AppDestination.allCases {
      XCTAssertFalse(destination.label.isEmpty, "\(destination) missing label")
    }
  }

  func testEachCaseHasSystemImage() {
    for destination in AppDestination.allCases {
      XCTAssertFalse(destination.systemImage.isEmpty, "\(destination) missing systemImage")
    }
  }

  func testIdentifiable() {
    let ids = Set(AppDestination.allCases.map(\.id))
    XCTAssertEqual(ids.count, AppDestination.allCases.count, "IDs must be unique")
  }
}
