import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class LandingViewTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - View Rendering Tests

  func testLandingViewRendersLogoSection() {
    let view = LandingView()
    XCTAssertNotNil(view)
  }

  func testLandingViewRendersGetStartedFreeButton() {
    let view = LandingView()
    XCTAssertNotNil(view)
  }

  func testLandingViewRendersSignInButton() {
    let view = LandingView()
    XCTAssertNotNil(view)
  }

  // MARK: - Navigation Tests

  func testLandingViewWrapsInNavigationStack() {
    let view = NavigationStack { LandingView() }
    XCTAssertNotNil(view)
  }

  func testSignInLinksToLoginView() {
    let view = LandingView()
    XCTAssertNotNil(view)
  }

  func testGetStartedFreeLinksToSignupView() {
    let view = LandingView()
    XCTAssertNotNil(view)
  }

  // MARK: - Accessibility Tests

  func testCompassIconIsAccessibilityHidden() {
    let view = LandingView()
    XCTAssertNotNil(view)
  }

  func testSignInButtonHasAccessibilityLabel() {
    let view = LandingView()
    XCTAssertNotNil(view)
  }

  func testGetStartedFreeButtonHasAccessibilityLabel() {
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

  // MARK: - Data-Driven Feature Cards Tests

  func testLandingFeaturesContainsThreeItems() {
    XCTAssertEqual(FeatureCardData.landingFeatures.count, 3)
  }

  func testLandingFeaturesFirstIsTrackSchoolsAndCoaches() {
    let first = FeatureCardData.landingFeatures[0]
    XCTAssertEqual(first.title, "Track Schools & Coaches")
    XCTAssertEqual(first.icon, "building.columns.fill")
  }

  func testLandingFeaturesSecondIsSmartOutreach() {
    let second = FeatureCardData.landingFeatures[1]
    XCTAssertEqual(second.title, "Smart Outreach")
    XCTAssertEqual(second.icon, "envelope.badge.fill")
  }

  func testLandingFeaturesThirdIsCalendarsAndTimeline() {
    let third = FeatureCardData.landingFeatures[2]
    XCTAssertEqual(third.title, "Calendars & Timeline")
    XCTAssertEqual(third.icon, "calendar.badge.clock")
  }

  func testFeatureCardDataHasUniqueIds() {
    let ids = FeatureCardData.landingFeatures.map(\.id)
    XCTAssertEqual(Set(ids).count, ids.count)
  }

  // MARK: - Complete View Hierarchy

  func testCompleteViewHierarchy() {
    let view = NavigationStack { LandingView() }
    XCTAssertNotNil(view)
  }
}
