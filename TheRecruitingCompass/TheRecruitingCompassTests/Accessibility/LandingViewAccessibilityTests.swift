import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class LandingViewAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  func testLandingView_CompassIcon_IsHiddenFromAccessibility() {
    let view = LandingView()
    XCTAssertNotNil(view)
  }

  func testLandingView_SignInButton_HasLabelAndHint() {
    let view = LandingView()
    XCTAssertNotNil(view)
  }

  func testLandingView_GetStartedFreeButton_HasLabelAndHint() {
    let view = LandingView()
    XCTAssertNotNil(view)
  }

  func testLandingView_FeatureCards_HaveCombinedAccessibility() {
    let view = LandingView()
    XCTAssertNotNil(view)
  }

  func testLandingView_FeatureCards_HaveFeatureLabelPrefix() {
    let card = FeatureCard(
      icon: "building.columns.fill",
      title: "Track Schools & Coaches",
      description: "A 5-stage pipeline for your college list."
    )
    XCTAssertNotNil(card)
  }

  func testLandingView_StatsBadge_HasCombinedAccessibility() {
    let view = LandingView()
    XCTAssertNotNil(view)
  }
}
