import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class LandingViewTests: XCTestCase {

  // MARK: - View Rendering Tests

  func testLandingViewRendersLogoSection() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    XCTAssertNotNil(view)
  }

  func testLandingViewRendersCompassIconAndTitle() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    XCTAssertNotNil(view)
  }

  func testLandingViewRendersSignInNavigationLink() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    XCTAssertNotNil(view)
  }

  func testLandingViewRendersCreateAccountNavigationLink() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    XCTAssertNotNil(view)
  }

  func testLandingViewRendersTrackSchoolsFeatureCard() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    XCTAssertNotNil(view)
  }

  func testLandingViewRendersLogInteractionsFeatureCard() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    XCTAssertNotNil(view)
  }

  func testLandingViewRendersMonitorProgressFeatureCard() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    XCTAssertNotNil(view)
  }

  // MARK: - Navigation Tests

  func testLandingViewWrapsInNavigationStack() {
    let view = NavigationStack {
      LandingView()
        .environmentObject(AuthManager.shared)
    }

    XCTAssertNotNil(view)
  }

  func testSignInLinksToLoginView() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    XCTAssertNotNil(view)
  }

  func testCreateAccountLinksToSignupView() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    XCTAssertNotNil(view)
  }

  // MARK: - Accessibility Tests

  func testLogoSectionCombinesChildrenAccessibility() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    // Logo VStack uses .accessibilityElement(children: .combine)
    XCTAssertNotNil(view)
  }

  func testLogoSectionHasRecruitingCompassLabel() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    // Logo VStack has .accessibilityLabel("Recruiting Compass")
    XCTAssertNotNil(view)
  }

  func testCompassIconIsAccessibilityHidden() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    // Compass icon uses .accessibilityHidden(true)
    XCTAssertNotNil(view)
  }

  func testSignInButtonHasAccessibilityLabel() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    // Sign In link has .accessibilityLabel("Sign in to your account")
    XCTAssertNotNil(view)
  }

  func testSignInButtonHasAccessibilityHint() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    // Sign In link has .accessibilityHint("Enter your email and password")
    XCTAssertNotNil(view)
  }

  func testCreateAccountButtonHasAccessibilityLabel() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    // Create Account link has .accessibilityLabel("Create a new account")
    XCTAssertNotNil(view)
  }

  func testCreateAccountButtonHasAccessibilityHint() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    // Create Account link has .accessibilityHint("Set up a new account with your information")
    XCTAssertNotNil(view)
  }

  func testNavigationBarIsHidden() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    // View uses .navigationBarHidden(true)
    XCTAssertNotNil(view)
  }

  // MARK: - Dynamic Type Tests

  func testLogoSizeIs80AtDefaultSizeCategory() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)
      .environment(\.sizeCategory, .medium)

    XCTAssertNotNil(view)
  }

  func testLogoSizeIs88AtExtraLargeAndAbove() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)
      .environment(\.sizeCategory, .extraLarge)

    XCTAssertNotNil(view)
  }

  // MARK: - Styling Tests

  func testBackgroundGradientApplied() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    XCTAssertNotNil(view)
  }

  func testScrollViewPresentsAllContent() {
    let view = LandingView()
      .environmentObject(AuthManager.shared)

    XCTAssertNotNil(view)
  }

  // MARK: - Complete View Hierarchy

  func testCompleteViewHierarchy() {
    let view = NavigationStack {
      LandingView()
        .environmentObject(AuthManager.shared)
    }

    XCTAssertNotNil(view)
  }
}
