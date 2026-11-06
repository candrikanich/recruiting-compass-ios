import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class BadgeColorTests: XCTestCase {

  func test_blue_usesForestRamp() {
    XCTAssertEqual(BadgeColor.blue.backgroundColor, Color.Brand.forest200)
    XCTAssertEqual(BadgeColor.blue.foregroundColor, Color.Brand.forest900)
    XCTAssertEqual(BadgeColor.blue.indicatorColor, Color.Brand.forest500)
  }

  func test_purple_usesGoldRamp() {
    XCTAssertEqual(BadgeColor.purple.backgroundColor, Color.Brand.gold200)
    XCTAssertEqual(BadgeColor.purple.foregroundColor, Color.Brand.gold900)
    XCTAssertEqual(BadgeColor.purple.indicatorColor, Color.Brand.gold500)
  }

  func test_emerald_usesEmerald200And900() {
    XCTAssertEqual(BadgeColor.emerald.backgroundColor, Color.Brand.emerald200)
    XCTAssertEqual(BadgeColor.emerald.foregroundColor, Color.Brand.emerald900)
  }

  func test_red_usesRed200And900() {
    XCTAssertEqual(BadgeColor.red.backgroundColor, Color.Brand.red200)
    XCTAssertEqual(BadgeColor.red.foregroundColor, Color.Brand.red900)
  }

  func test_slate_usesWarmNeutralRamp() {
    XCTAssertEqual(BadgeColor.slate.backgroundColor, Color.Brand.slate200)
    XCTAssertEqual(BadgeColor.slate.foregroundColor, Color.Brand.slate900)
    XCTAssertEqual(BadgeColor.slate.indicatorColor, Color.Brand.slate500)
  }

  func test_allCases_haveDistinctBackgroundColors() {
    let backgroundColors = BadgeColor.allCases.map(\.backgroundColor)
    XCTAssertEqual(Set(backgroundColors).count, BadgeColor.allCases.count, "Each case should have a distinct background color")
  }

  func test_allCases_haveDistinctForegroundColors() {
    let foregroundColors = BadgeColor.allCases.map(\.foregroundColor)
    XCTAssertEqual(Set(foregroundColors).count, BadgeColor.allCases.count, "Each case should have a distinct foreground color")
  }

  func test_allCases_haveDistinctIndicatorColors() {
    let indicatorColors = BadgeColor.allCases.map(\.indicatorColor)
    XCTAssertEqual(Set(indicatorColors).count, BadgeColor.allCases.count, "Each case should have a distinct indicator color")
  }

  func test_allCasesCount() {
    XCTAssertEqual(BadgeColor.allCases.count, 6)
  }
}
