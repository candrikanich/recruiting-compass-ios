import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class BadgeColorTests: XCTestCase {

  func test_blue_backgroundColor_usesBrandBlue100() {
    XCTAssertEqual(BadgeColor.blue.backgroundColor, Color.Brand.blue100)
  }

  func test_blue_foregroundColor_usesBrandBlue700() {
    XCTAssertEqual(BadgeColor.blue.foregroundColor, Color.Brand.blue700)
  }

  func test_emerald_backgroundColor_usesBrandEmerald100() {
    XCTAssertEqual(BadgeColor.emerald.backgroundColor, Color.Brand.emerald100)
  }

  func test_red_foregroundColor_usesBrandRed700() {
    XCTAssertEqual(BadgeColor.red.foregroundColor, Color.Brand.red700)
  }

  func test_slate_indicatorColor_usesBrandSlate500() {
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
