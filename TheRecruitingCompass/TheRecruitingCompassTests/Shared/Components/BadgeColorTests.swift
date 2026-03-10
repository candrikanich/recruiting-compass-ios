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

  func test_allCases_haveNonNilColors() {
    for color in BadgeColor.allCases {
      _ = color.backgroundColor
      _ = color.foregroundColor
      _ = color.indicatorColor
    }
  }

  func test_allCasesCount() {
    XCTAssertEqual(BadgeColor.allCases.count, 6)
  }
}
