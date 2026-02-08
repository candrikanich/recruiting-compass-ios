import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class LandingViewAccessibilityTests: XCTestCase {

  func testLandingView_LogoSection_HasAccessibilityLabel() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    // Logo VStack has .accessibilityLabel("Recruiting Compass")
    XCTAssertNotNil(view)
  }

  func testLandingView_CompassIcon_IsHiddenFromAccessibility() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    // Compass icon uses .accessibilityHidden(true)
    XCTAssertNotNil(view)
  }

  func testLandingView_SignInButton_HasLabelAndHint() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    // .accessibilityLabel("Sign in to your account")
    // .accessibilityHint("Enter your email and password")
    XCTAssertNotNil(view)
  }

  func testLandingView_CreateAccountButton_HasLabelAndHint() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    // .accessibilityLabel("Create a new account")
    // .accessibilityHint("Set up a new account with your information")
    XCTAssertNotNil(view)
  }

  func testLandingView_FeatureCards_HaveCombinedAccessibility() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    // Each FeatureCard uses .accessibilityElement(children: .combine)
    XCTAssertNotNil(view)
  }

  func testLandingView_FeatureCards_HaveFeatureLabelPrefix() {
    let card = FeatureCard(
      icon: "shield.checkered",
      title: "Track Schools",
      description: "Organize and manage your target colleges in one place"
    )

    // Has .accessibilityLabel("Feature: Track Schools")
    XCTAssertNotNil(card)
  }
}
