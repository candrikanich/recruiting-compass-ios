import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class LandingViewAccessibilityTests: XCTestCase {

  func testLandingView_LogoSection_HasAccessibilityLabel() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testLandingView_CompassIcon_IsHiddenFromAccessibility() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testLandingView_SignInButton_HasLabelAndHint() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testLandingView_CreateAccountButton_HasLabelAndHint() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testLandingView_FeatureCards_HaveCombinedAccessibility() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testLandingView_FeatureCards_HaveFeatureLabelPrefix() {
    let card = FeatureCard(
      icon: "shield.checkered",
      title: "Track Schools",
      description: "Organize and manage your target colleges in one place"
    )

    XCTAssertNotNil(card)
  }
}
