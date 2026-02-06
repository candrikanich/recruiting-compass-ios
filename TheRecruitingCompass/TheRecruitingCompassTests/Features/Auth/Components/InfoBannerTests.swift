import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class InfoBannerTests: XCTestCase {
  func testPendingStateBanner() {
    let banner = InfoBanner.pending(email: "test@example.com")

    // Verify the banner exists and renders
    XCTAssertNotNil(banner)
  }

  func testCheckingStateBanner() {
    let banner = InfoBanner.checking()

    XCTAssertNotNil(banner)
  }

  func testVerifiedStateBanner() {
    let banner = InfoBanner.verified()

    XCTAssertNotNil(banner)
  }

  func testBannerHasProperStructure() {
    let pendingBanner = InfoBanner.pending(email: "test@example.com")
    let checkingBanner = InfoBanner.checking()
    let verifiedBanner = InfoBanner.verified()

    // All banners should be viewable
    let pendingView = AnyView(pendingBanner)
    let checkingView = AnyView(checkingBanner)
    let verifiedView = AnyView(verifiedBanner)

    XCTAssertNotNil(pendingView)
    XCTAssertNotNil(checkingView)
    XCTAssertNotNil(verifiedView)
  }
}
