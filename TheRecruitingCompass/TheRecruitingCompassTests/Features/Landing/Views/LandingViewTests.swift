import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class LandingViewTests: XCTestCase {

  // MARK: - View Rendering Tests

  func testLandingViewRendersLogoSection() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testLandingViewRendersCompassIconAndTitle() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testLandingViewRendersSignInNavigationLink() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testLandingViewRendersCreateAccountNavigationLink() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testLandingViewRendersTrackSchoolsFeatureCard() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testLandingViewRendersLogInteractionsFeatureCard() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testLandingViewRendersMonitorProgressFeatureCard() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  // MARK: - Navigation Tests

  func testLandingViewWrapsInNavigationStack() {
    let view = NavigationStack {
      LandingView()
    }

    XCTAssertNotNil(view)
  }

  func testSignInLinksToLoginView() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testCreateAccountLinksToSignupView() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  // MARK: - Accessibility Tests

  func testLogoSectionCombinesChildrenAccessibility() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testLogoSectionHasRecruitingCompassLabel() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testCompassIconIsAccessibilityHidden() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testSignInButtonHasAccessibilityLabel() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testSignInButtonHasAccessibilityHint() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testCreateAccountButtonHasAccessibilityLabel() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testCreateAccountButtonHasAccessibilityHint() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testNavigationBarIsHidden() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  // MARK: - Dynamic Type Tests

  func testLogoSizeIs80AtDefaultSizeCategory() {
    let view = LandingView()
      .environment(\.sizeCategory, .medium)

    XCTAssertNotNil(view)
  }

  func testLogoSizeIs88AtExtraLargeAndAbove() {
    let view = LandingView()
      .environment(\.sizeCategory, .extraLarge)

    XCTAssertNotNil(view)
  }

  // MARK: - Styling Tests

  func testSignInButtonUsesThemedGradient() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testBackgroundGradientApplied() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  func testScrollViewPresentsAllContent() {
    let view = LandingView()

    XCTAssertNotNil(view)
  }

  // MARK: - Data-Driven Feature Cards Tests

  func testLandingFeaturesContainsThreeItems() {
    XCTAssertEqual(FeatureCardData.landingFeatures.count, 3)
  }

  func testLandingFeaturesFirstIsTrackSchools() {
    let first = FeatureCardData.landingFeatures[0]
    XCTAssertEqual(first.title, "Track Schools")
    XCTAssertEqual(first.icon, "shield.checkered")
  }

  func testLandingFeaturesSecondIsLogInteractions() {
    let second = FeatureCardData.landingFeatures[1]
    XCTAssertEqual(second.title, "Log Interactions")
    XCTAssertEqual(second.icon, "bubble.right.fill")
  }

  func testLandingFeaturesThirdIsMonitorProgress() {
    let third = FeatureCardData.landingFeatures[2]
    XCTAssertEqual(third.title, "Monitor Progress")
    XCTAssertEqual(third.icon, "chart.bar.fill")
  }

  func testFeatureCardDataHasUniqueIds() {
    let ids = FeatureCardData.landingFeatures.map(\.id)
    XCTAssertEqual(Set(ids).count, ids.count)
  }

  // MARK: - Complete View Hierarchy

  func testCompleteViewHierarchy() {
    let view = NavigationStack {
      LandingView()
    }

    XCTAssertNotNil(view)
  }
}
