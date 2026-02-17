import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AnalyticsSummaryTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInitialization_WithAllFields() {
    let trend = AnalyticsSummary.TrendData(schools: 5.0, interactions: 12.0, offers: -3.0)
    let summary = AnalyticsSummary(
      totalSchools: 24,
      totalInteractions: 87,
      totalOffers: 15,
      commitments: 3,
      trends: trend
    )

    XCTAssertEqual(summary.totalSchools, 24)
    XCTAssertEqual(summary.totalInteractions, 87)
    XCTAssertEqual(summary.totalOffers, 15)
    XCTAssertEqual(summary.commitments, 3)
    XCTAssertNotNil(summary.trends)
    XCTAssertEqual(summary.trends?.schools, 5.0)
    XCTAssertEqual(summary.trends?.interactions, 12.0)
    XCTAssertEqual(summary.trends?.offers, -3.0)
  }

  func testInitialization_WithNilTrends() {
    let summary = AnalyticsSummary(
      totalSchools: 10,
      totalInteractions: 50,
      totalOffers: 5,
      commitments: 1,
      trends: nil
    )

    XCTAssertNil(summary.trends)
  }

  func testEmpty_StaticProperty() {
    let empty = AnalyticsSummary.empty

    XCTAssertEqual(empty.totalSchools, 0)
    XCTAssertEqual(empty.totalInteractions, 0)
    XCTAssertEqual(empty.totalOffers, 0)
    XCTAssertEqual(empty.commitments, 0)
    XCTAssertNil(empty.trends)
  }

  // MARK: - Codable Tests

  func testDecodingFromJSON_WithSnakeCaseKeys() throws {
    let json = """
    {
      "total_schools": 24,
      "total_interactions": 87,
      "total_offers": 15,
      "commitments": 3,
      "trends": {
        "schools": 5.0,
        "interactions": 12.0,
        "offers": -5.0
      }
    }
    """.data(using: .utf8)!

    let summary = try JSONDecoder().decode(AnalyticsSummary.self, from: json)

    XCTAssertEqual(summary.totalSchools, 24)
    XCTAssertEqual(summary.totalInteractions, 87)
    XCTAssertEqual(summary.totalOffers, 15)
    XCTAssertEqual(summary.commitments, 3)
    XCTAssertEqual(summary.trends?.schools, 5.0)
    XCTAssertEqual(summary.trends?.interactions, 12.0)
    XCTAssertEqual(summary.trends?.offers, -5.0)
  }

  func testDecodingFromJSON_WithNullTrends() throws {
    let json = """
    {
      "total_schools": 10,
      "total_interactions": 0,
      "total_offers": 0,
      "commitments": 0,
      "trends": null
    }
    """.data(using: .utf8)!

    let summary = try JSONDecoder().decode(AnalyticsSummary.self, from: json)

    XCTAssertEqual(summary.totalSchools, 10)
    XCTAssertNil(summary.trends)
  }

  func testDecodingFromJSON_WithMissingTrends() throws {
    let json = """
    {
      "total_schools": 5,
      "total_interactions": 20,
      "total_offers": 2,
      "commitments": 0
    }
    """.data(using: .utf8)!

    let summary = try JSONDecoder().decode(AnalyticsSummary.self, from: json)

    XCTAssertEqual(summary.totalSchools, 5)
    XCTAssertNil(summary.trends)
  }

  func testEncodingAndDecoding_RoundTrip() throws {
    let trend = AnalyticsSummary.TrendData(schools: 10.0, interactions: -5.0, offers: 0.0)
    let original = AnalyticsSummary(
      totalSchools: 30,
      totalInteractions: 100,
      totalOffers: 8,
      commitments: 2,
      trends: trend
    )

    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(AnalyticsSummary.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  func testEncodingAndDecoding_RoundTrip_NilTrends() throws {
    let original = AnalyticsSummary.empty

    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(AnalyticsSummary.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  // MARK: - Equatable Tests

  func testEquatable_EqualSummaries() {
    let trend = AnalyticsSummary.TrendData(schools: 5.0, interactions: 10.0, offers: -2.0)
    let summary1 = AnalyticsSummary(totalSchools: 10, totalInteractions: 50, totalOffers: 5, commitments: 1, trends: trend)
    let summary2 = AnalyticsSummary(totalSchools: 10, totalInteractions: 50, totalOffers: 5, commitments: 1, trends: trend)

    XCTAssertEqual(summary1, summary2)
  }

  func testEquatable_DifferentValues() {
    let summary1 = AnalyticsSummary(totalSchools: 10, totalInteractions: 50, totalOffers: 5, commitments: 1, trends: nil)
    let summary2 = AnalyticsSummary(totalSchools: 20, totalInteractions: 50, totalOffers: 5, commitments: 1, trends: nil)

    XCTAssertNotEqual(summary1, summary2)
  }

  func testEquatable_NilVsNonNilTrends() {
    let trend = AnalyticsSummary.TrendData(schools: 0, interactions: 0, offers: 0)
    let summary1 = AnalyticsSummary(totalSchools: 10, totalInteractions: 50, totalOffers: 5, commitments: 1, trends: nil)
    let summary2 = AnalyticsSummary(totalSchools: 10, totalInteractions: 50, totalOffers: 5, commitments: 1, trends: trend)

    XCTAssertNotEqual(summary1, summary2)
  }

  // MARK: - TrendData Tests

  func testTrendData_PositiveTrendLabels() {
    let trend = AnalyticsSummary.TrendData(schools: 5.0, interactions: 12.0, offers: 3.0)

    XCTAssertEqual(trend.schoolsTrendLabel, "+5% vs last period")
    XCTAssertEqual(trend.interactionsTrendLabel, "+12% vs last period")
    XCTAssertEqual(trend.offersTrendLabel, "+3% vs last period")
  }

  func testTrendData_NegativeTrendLabels() {
    let trend = AnalyticsSummary.TrendData(schools: -5.0, interactions: -12.0, offers: -3.0)

    XCTAssertEqual(trend.schoolsTrendLabel, "-5% vs last period")
    XCTAssertEqual(trend.interactionsTrendLabel, "-12% vs last period")
    XCTAssertEqual(trend.offersTrendLabel, "-3% vs last period")
  }

  func testTrendData_ZeroTrendLabel() {
    let trend = AnalyticsSummary.TrendData(schools: 0.0, interactions: 0.0, offers: 0.0)

    XCTAssertEqual(trend.schoolsTrendLabel, "+0% vs last period")
    XCTAssertEqual(trend.interactionsTrendLabel, "+0% vs last period")
    XCTAssertEqual(trend.offersTrendLabel, "+0% vs last period")
  }

  func testTrendData_FractionalValues_TruncatesToInt() {
    let trend = AnalyticsSummary.TrendData(schools: 5.7, interactions: -3.2, offers: 0.9)

    XCTAssertEqual(trend.schoolsTrendLabel, "+5% vs last period")
    XCTAssertEqual(trend.interactionsTrendLabel, "-3% vs last period")
    XCTAssertEqual(trend.offersTrendLabel, "+0% vs last period")
  }

  // MARK: - Edge Cases

  func testDecodingWithZeroValues() throws {
    let json = """
    {
      "total_schools": 0,
      "total_interactions": 0,
      "total_offers": 0,
      "commitments": 0,
      "trends": null
    }
    """.data(using: .utf8)!

    let summary = try JSONDecoder().decode(AnalyticsSummary.self, from: json)

    XCTAssertEqual(summary.totalSchools, 0)
    XCTAssertEqual(summary.totalInteractions, 0)
    XCTAssertEqual(summary.totalOffers, 0)
    XCTAssertEqual(summary.commitments, 0)
  }

  func testDecodingWithLargeValues() throws {
    let json = """
    {
      "total_schools": 999999,
      "total_interactions": 1000000,
      "total_offers": 500000,
      "commitments": 100000,
      "trends": {
        "schools": 999.9,
        "interactions": -999.9,
        "offers": 0.0
      }
    }
    """.data(using: .utf8)!

    let summary = try JSONDecoder().decode(AnalyticsSummary.self, from: json)

    XCTAssertEqual(summary.totalSchools, 999999)
    XCTAssertEqual(summary.totalInteractions, 1000000)
    XCTAssertEqual(summary.trends?.schools, 999.9)
  }

  func testDecodingWithInvalidJSON_MissingRequiredField() {
    let json = """
    {
      "total_schools": 10,
      "total_interactions": 50,
      "total_offers": 5
    }
    """.data(using: .utf8)!

    XCTAssertThrowsError(try JSONDecoder().decode(AnalyticsSummary.self, from: json))
  }

  func testDecodingWithWrongType_StringInsteadOfInt() {
    let json = """
    {
      "total_schools": "ten",
      "total_interactions": 50,
      "total_offers": 5,
      "commitments": 1
    }
    """.data(using: .utf8)!

    XCTAssertThrowsError(try JSONDecoder().decode(AnalyticsSummary.self, from: json))
  }
}
