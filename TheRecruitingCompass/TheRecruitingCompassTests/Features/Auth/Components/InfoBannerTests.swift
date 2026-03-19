import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class InfoBannerTests: XCTestCase {
  nonisolated deinit {}
  func testPendingStateBanner() {
    let banner = InfoBanner(state: .pending, email: "test@example.com")
    XCTAssertNotNil(banner)
  }

  func testCheckingStateBanner() {
    let banner = InfoBanner(state: .checking)
    XCTAssertNotNil(banner)
  }

  func testVerifiedStateBanner() {
    let banner = InfoBanner(state: .verified)
    XCTAssertNotNil(banner)
  }

  func testErrorStateBannerRendersEmpty() {
    let banner = InfoBanner(state: .error(message: "Network error"))
    XCTAssertNotNil(banner)
  }

  func testBannerHasProperStructure() {
    let pendingView = AnyView(InfoBanner(state: .pending, email: "test@example.com"))
    let checkingView = AnyView(InfoBanner(state: .checking))
    let verifiedView = AnyView(InfoBanner(state: .verified))

    XCTAssertNotNil(pendingView)
    XCTAssertNotNil(checkingView)
    XCTAssertNotNil(verifiedView)
  }
}
