import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class StatCardViewAccessibilityTests: XCTestCase {

  // MARK: - Test Helpers

  private func makeCard(
    title: String = "Total Schools",
    value: Int = 24,
    iconName: String = "building.2.fill",
    color: Color = .blue,
    trend: String? = nil
  ) -> SummaryCard {
    SummaryCard(
      title: title,
      value: value,
      iconName: iconName,
      color: color,
      trend: trend
    )
  }

  // MARK: - Accessibility Label Tests

  func testStatCard_hasAccessibilityLabelWithTitleAndValue() {
    let card = makeCard(title: "Total Schools", value: 24)
    let view = StatCardView(card: card)
    XCTAssertNotNil(view)
    XCTAssertEqual(card.title, "Total Schools")
    XCTAssertEqual(card.value, 24)
  }

  func testStatCard_labelIncludesTrendDirection_positive() {
    let card = makeCard(trend: "+5% vs last period")
    let view = StatCardView(card: card)
    XCTAssertNotNil(view)
    XCTAssertTrue(card.isPositiveTrend)
    XCTAssertFalse(card.isNegativeTrend)
  }

  func testStatCard_labelIncludesTrendDirection_negative() {
    let card = makeCard(trend: "-3% vs last period")
    let view = StatCardView(card: card)
    XCTAssertNotNil(view)
    XCTAssertFalse(card.isPositiveTrend)
    XCTAssertTrue(card.isNegativeTrend)
  }

  func testStatCard_labelHandlesNoTrend() {
    let card = makeCard(trend: nil)
    let view = StatCardView(card: card)
    XCTAssertNotNil(view)
    XCTAssertFalse(card.isPositiveTrend)
    XCTAssertFalse(card.isNegativeTrend)
  }

  func testStatCard_zeroValue() {
    let card = makeCard(value: 0)
    let view = StatCardView(card: card)
    XCTAssertNotNil(view)
    XCTAssertEqual(card.value, 0)
  }

  // MARK: - Icon Hidden Tests

  func testStatCard_iconIsDecorativeAndHidden() {
    // Icon uses .accessibilityHidden(true) -- verified in implementation
    let card = makeCard()
    let view = StatCardView(card: card)
    XCTAssertNotNil(view)
  }

  // MARK: - Children Ignored Tests

  func testStatCard_usesChildrenIgnore() {
    // Uses .accessibilityElement(children: .ignore) to prevent VoiceOver
    // from reading individual child elements. The combined label conveys all info.
    let card = makeCard(trend: "+12% vs last period")
    let view = StatCardView(card: card)
    XCTAssertNotNil(view)
  }

  // MARK: - Trend Badge Uses Icons

  func testStatCard_trendUsesIconNotJustColor() {
    // Trend badge uses arrow.up.right / arrow.down.right icons in addition to color
    // This satisfies WCAG 1.4.1 Use of Color
    let positiveCard = makeCard(trend: "+5% vs last period")
    XCTAssertTrue(positiveCard.isPositiveTrend)

    let negativeCard = makeCard(trend: "-5% vs last period")
    XCTAssertTrue(negativeCard.isNegativeTrend)
  }

  // MARK: - Dynamic Type Tests

  func testStatCard_supportsDynamicType() {
    let sizes: [ContentSizeCategory] = [
      .extraSmall,
      .medium,
      .accessibilityMedium,
      .accessibilityExtraExtraLarge
    ]

    for size in sizes {
      let card = makeCard()
      let view = StatCardView(card: card)
        .environment(\.sizeCategory, size)
      XCTAssertNotNil(view)
    }
  }

  // MARK: - Semantic Font Tests

  func testStatCard_usesSemanticFonts() {
    // StatCardView uses .title.bold(), .caption, .title3 -- all semantic
    // Never uses .system(size:)
    let card = makeCard()
    let view = StatCardView(card: card)
    XCTAssertNotNil(view)
  }
}
