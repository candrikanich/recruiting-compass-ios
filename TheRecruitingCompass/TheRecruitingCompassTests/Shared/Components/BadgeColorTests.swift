import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class BadgeColorTests: XCTestCase {

  func test_blue_backgroundColor_usesBrandBlue100() {
    XCTAssertEqual(BadgeColor.blue.backgroundColor, Color.brand.blue100)
  }

  func test_blue_foregroundColor_usesBrandBlue700() {
    XCTAssertEqual(BadgeColor.blue.foregroundColor, Color.brand.blue700)
  }

  func test_emerald_backgroundColor_usesBrandEmerald100() {
    XCTAssertEqual(BadgeColor.emerald.backgroundColor, Color.brand.emerald100)
  }

  func test_red_foregroundColor_usesBrandRed700() {
    XCTAssertEqual(BadgeColor.red.foregroundColor, Color.brand.red700)
  }

  func test_slate_indicatorColor_usesBrandSlate500() {
    XCTAssertEqual(BadgeColor.slate.indicatorColor, Color.brand.slate500)
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
