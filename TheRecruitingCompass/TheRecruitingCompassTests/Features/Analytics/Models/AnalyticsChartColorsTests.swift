import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class AnalyticsChartColorsTests: XCTestCase {

  // MARK: - Palette Tests

  func testPalette_ContainsSixColors() {
    XCTAssertEqual(AnalyticsChartColors.palette.count, 6)
  }

  func testPalette_ContainsNamedColors() {
    XCTAssertEqual(AnalyticsChartColors.palette[0], AnalyticsChartColors.primary)
    XCTAssertEqual(AnalyticsChartColors.palette[1], AnalyticsChartColors.secondary)
    XCTAssertEqual(AnalyticsChartColors.palette[2], AnalyticsChartColors.tertiary)
    XCTAssertEqual(AnalyticsChartColors.palette[3], AnalyticsChartColors.quaternary)
    XCTAssertEqual(AnalyticsChartColors.palette[4], AnalyticsChartColors.purple)
    XCTAssertEqual(AnalyticsChartColors.palette[5], AnalyticsChartColors.pink)
  }

  // MARK: - Color At Index Tests

  func testColorAtIndex_ReturnsCorrectColor() {
    XCTAssertEqual(AnalyticsChartColors.color(at: 0), AnalyticsChartColors.primary)
    XCTAssertEqual(AnalyticsChartColors.color(at: 1), AnalyticsChartColors.secondary)
    XCTAssertEqual(AnalyticsChartColors.color(at: 5), AnalyticsChartColors.pink)
  }

  func testColorAtIndex_WrapsAround() {
    XCTAssertEqual(AnalyticsChartColors.color(at: 6), AnalyticsChartColors.primary)
    XCTAssertEqual(AnalyticsChartColors.color(at: 7), AnalyticsChartColors.secondary)
    XCTAssertEqual(AnalyticsChartColors.color(at: 12), AnalyticsChartColors.primary)
  }

  // MARK: - Funnel Palette Tests

  func testFunnelPalette_ContainsFourColors() {
    XCTAssertEqual(AnalyticsChartColors.funnelPalette.count, 4)
  }

  func testFunnelPalette_ContainsExpectedColors() {
    XCTAssertEqual(AnalyticsChartColors.funnelPalette[0], AnalyticsChartColors.primary)
    XCTAssertEqual(AnalyticsChartColors.funnelPalette[1], AnalyticsChartColors.secondary)
    XCTAssertEqual(AnalyticsChartColors.funnelPalette[2], AnalyticsChartColors.tertiary)
    XCTAssertEqual(AnalyticsChartColors.funnelPalette[3], AnalyticsChartColors.quaternary)
  }

  // MARK: - Sentiment Colors Tests

  func testSentimentColors_ContainsFourEntries() {
    XCTAssertEqual(AnalyticsChartColors.sentimentColors.count, 4)
  }

  func testSentimentColors_ContainsExpectedKeys() {
    XCTAssertNotNil(AnalyticsChartColors.sentimentColors["Positive"])
    XCTAssertNotNil(AnalyticsChartColors.sentimentColors["Very Positive"])
    XCTAssertNotNil(AnalyticsChartColors.sentimentColors["Neutral"])
    XCTAssertNotNil(AnalyticsChartColors.sentimentColors["Negative"])
  }

  func testSentimentColors_PositiveUsesSecondary() {
    XCTAssertEqual(AnalyticsChartColors.sentimentColors["Positive"], AnalyticsChartColors.secondary)
  }

  func testSentimentColors_NegativeUsesQuaternary() {
    XCTAssertEqual(AnalyticsChartColors.sentimentColors["Negative"], AnalyticsChartColors.quaternary)
  }

  func testSentimentColors_UnknownKeyReturnsNil() {
    XCTAssertNil(AnalyticsChartColors.sentimentColors["Unknown"])
  }
}
