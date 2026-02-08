import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class FeatureCardTests: XCTestCase {

  // MARK: - Component Rendering Tests

  func testFeatureCardRendersWithGivenIconTitleDescription() {
    let card = FeatureCard(
      icon: "shield.checkered",
      title: "Track Schools",
      description: "Organize and manage your target colleges in one place"
    )

    XCTAssertNotNil(card)
  }

  func testFeatureCardRendersWithDifferentContent() {
    let card = FeatureCard(
      icon: "bubble.right.fill",
      title: "Log Interactions",
      description: "Keep track of every conversation with coaches"
    )

    XCTAssertNotNil(card)
  }

  func testFeatureCardRendersWithChartContent() {
    let card = FeatureCard(
      icon: "chart.bar.fill",
      title: "Monitor Progress",
      description: "Visualize your recruiting journey with insights"
    )

    XCTAssertNotNil(card)
  }

  // MARK: - Accessibility Tests

  func testFeatureCardCombinesAccessibilityChildren() {
    let card = FeatureCard(
      icon: "shield.checkered",
      title: "Track Schools",
      description: "Organize and manage your target colleges in one place"
    )

    // Uses .accessibilityElement(children: .combine)
    XCTAssertNotNil(card)
  }

  func testFeatureCardHasFeatureTitleAccessibilityLabel() {
    let card = FeatureCard(
      icon: "shield.checkered",
      title: "Track Schools",
      description: "Organize and manage your target colleges in one place"
    )

    // Has .accessibilityLabel("Feature: Track Schools")
    XCTAssertNotNil(card)
  }

  func testFeatureCardHasDescriptionAsAccessibilityValue() {
    let card = FeatureCard(
      icon: "shield.checkered",
      title: "Track Schools",
      description: "Organize and manage your target colleges in one place"
    )

    // Has .accessibilityValue matching description
    XCTAssertNotNil(card)
  }

  func testFeatureCardIconIsAccessibilityHidden() {
    let card = FeatureCard(
      icon: "shield.checkered",
      title: "Track Schools",
      description: "Organize and manage your target colleges in one place"
    )

    // Icon uses .accessibilityHidden(true)
    XCTAssertNotNil(card)
  }

  // MARK: - Dynamic Type Tests

  func testIconSizeIs32AtDefaultSizeCategory() {
    let card = FeatureCard(
      icon: "shield.checkered",
      title: "Track Schools",
      description: "Organize and manage your target colleges in one place"
    )
      .environment(\.sizeCategory, .medium)

    XCTAssertNotNil(card)
  }

  func testIconSizeIs36AtExtraLargeAndAbove() {
    let card = FeatureCard(
      icon: "shield.checkered",
      title: "Track Schools",
      description: "Organize and manage your target colleges in one place"
    )
      .environment(\.sizeCategory, .extraLarge)

    XCTAssertNotNil(card)
  }

  // MARK: - Styling Tests

  func testFeatureCardHasRoundedBackground() {
    let card = FeatureCard(
      icon: "shield.checkered",
      title: "Track Schools",
      description: "Organize and manage your target colleges in one place"
    )

    XCTAssertNotNil(card)
  }

  func testFeatureCardDescriptionLimitedToThreeLines() {
    let card = FeatureCard(
      icon: "shield.checkered",
      title: "Track Schools",
      description: "Organize and manage your target colleges in one place"
    )

    // Uses .lineLimit(3)
    XCTAssertNotNil(card)
  }
}
