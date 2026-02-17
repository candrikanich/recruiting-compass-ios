import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AnalyticsAPIResponsesTests: XCTestCase {

  // MARK: - ChartDataItem Tests

  func testChartDataItem_Initialization() {
    let item = ChartDataItem(label: "Email", value: 34)

    XCTAssertEqual(item.label, "Email")
    XCTAssertEqual(item.value, 34)
  }

  func testChartDataItem_Equatable() {
    let item1 = ChartDataItem(label: "Email", value: 34)
    let item2 = ChartDataItem(label: "Email", value: 34)
    let item3 = ChartDataItem(label: "Phone", value: 28)

    XCTAssertEqual(item1, item2)
    XCTAssertNotEqual(item1, item3)
  }

  func testChartDataItem_Codable() throws {
    let json = """
    { "label": "Email", "value": 34 }
    """.data(using: .utf8)!

    let item = try JSONDecoder().decode(ChartDataItem.self, from: json)
    XCTAssertEqual(item.label, "Email")
    XCTAssertEqual(item.value, 34)
  }

  func testChartDataItem_RoundTrip() throws {
    let original = ChartDataItem(label: "Phone Call", value: 28)
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(ChartDataItem.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  // MARK: - AnalyticsSummaryResponse Tests

  func testAnalyticsSummaryResponse_Decoding() throws {
    let json = """
    {
      "success": true,
      "data": {
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
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(AnalyticsSummaryResponse.self, from: json)

    XCTAssertTrue(response.success)
    XCTAssertEqual(response.data.totalSchools, 24)
    XCTAssertEqual(response.data.totalInteractions, 87)
    XCTAssertEqual(response.data.totalOffers, 15)
    XCTAssertEqual(response.data.commitments, 3)
    XCTAssertEqual(response.data.trends?.schools, 5.0)
  }

  // MARK: - InteractionAnalyticsResponse Tests

  func testInteractionAnalyticsResponse_Decoding() throws {
    let json = """
    {
      "success": true,
      "data": {
        "by_type": [
          { "label": "Email", "value": 34 },
          { "label": "Phone Call", "value": 28 }
        ],
        "by_sentiment": [
          { "label": "Positive", "value": 52 },
          { "label": "Neutral", "value": 28 }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(InteractionAnalyticsResponse.self, from: json)

    XCTAssertTrue(response.success)
    XCTAssertEqual(response.data.byType.count, 2)
    XCTAssertEqual(response.data.byType[0].label, "Email")
    XCTAssertEqual(response.data.byType[0].value, 34)
    XCTAssertEqual(response.data.bySentiment.count, 2)
    XCTAssertEqual(response.data.bySentiment[0].label, "Positive")
  }

  func testInteractionAnalyticsResponse_EmptyArrays() throws {
    let json = """
    {
      "success": true,
      "data": {
        "by_type": [],
        "by_sentiment": []
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(InteractionAnalyticsResponse.self, from: json)

    XCTAssertTrue(response.data.byType.isEmpty)
    XCTAssertTrue(response.data.bySentiment.isEmpty)
  }

  // MARK: - PipelineResponse Tests

  func testPipelineResponse_Decoding() throws {
    let json = """
    {
      "success": true,
      "data": {
        "stages": [
          { "label": "Initial Contact", "value": 250 },
          { "label": "Active Discussions", "value": 85 },
          { "label": "Offers Extended", "value": 15 },
          { "label": "Committed", "value": 3 }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(PipelineResponse.self, from: json)

    XCTAssertTrue(response.success)
    XCTAssertEqual(response.data.stages.count, 4)
    XCTAssertEqual(response.data.stages[0].label, "Initial Contact")
    XCTAssertEqual(response.data.stages[0].value, 250)
    XCTAssertEqual(response.data.stages[3].label, "Committed")
    XCTAssertEqual(response.data.stages[3].value, 3)
  }

  func testPipelineResponse_EmptyStages() throws {
    let json = """
    {
      "success": true,
      "data": {
        "stages": []
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(PipelineResponse.self, from: json)

    XCTAssertTrue(response.data.stages.isEmpty)
  }

  // MARK: - SchoolAnalyticsResponse Tests

  func testSchoolAnalyticsResponse_Decoding() throws {
    let json = """
    {
      "success": true,
      "data": {
        "by_status": [
          { "label": "Active Recruiting", "value": 18 },
          { "label": "On Wait List", "value": 4 },
          { "label": "Passed", "value": 2 }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(SchoolAnalyticsResponse.self, from: json)

    XCTAssertTrue(response.success)
    XCTAssertEqual(response.data.byStatus.count, 3)
    XCTAssertEqual(response.data.byStatus[0].label, "Active Recruiting")
    XCTAssertEqual(response.data.byStatus[0].value, 18)
  }

  // MARK: - PerformanceCorrelationResponse Tests

  func testPerformanceCorrelationResponse_Decoding() throws {
    let json = """
    {
      "success": true,
      "data": {
        "datasets": [
          {
            "label": "Exit Velocity vs Distance",
            "points": [
              { "x": 85.0, "y": 340.0, "label": "Player A" },
              { "x": 90.0, "y": 380.0, "label": "Player B" }
            ]
          }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(PerformanceCorrelationResponse.self, from: json)

    XCTAssertTrue(response.success)
    XCTAssertEqual(response.data.datasets.count, 1)
    XCTAssertEqual(response.data.datasets[0].label, "Exit Velocity vs Distance")
    XCTAssertEqual(response.data.datasets[0].points.count, 2)
    XCTAssertEqual(response.data.datasets[0].points[0].x, 85.0)
    XCTAssertEqual(response.data.datasets[0].points[0].y, 340.0)
    XCTAssertEqual(response.data.datasets[0].points[0].label, "Player A")
  }

  func testPerformanceCorrelationResponse_MultipleDatasets() throws {
    let json = """
    {
      "success": true,
      "data": {
        "datasets": [
          {
            "label": "Dataset 1",
            "points": [{ "x": 1.0, "y": 2.0, "label": "P1" }]
          },
          {
            "label": "Dataset 2",
            "points": [{ "x": 3.0, "y": 4.0, "label": "P2" }]
          }
        ]
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(PerformanceCorrelationResponse.self, from: json)

    XCTAssertEqual(response.data.datasets.count, 2)
  }

  func testPerformanceCorrelationResponse_EmptyDatasets() throws {
    let json = """
    {
      "success": true,
      "data": {
        "datasets": []
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(PerformanceCorrelationResponse.self, from: json)

    XCTAssertTrue(response.data.datasets.isEmpty)
  }

  func testCorrelationPoint_NegativeValues() throws {
    let json = """
    { "x": -5.0, "y": -10.0, "label": "Negative" }
    """.data(using: .utf8)!

    let point = try JSONDecoder().decode(PerformanceCorrelationResponse.CorrelationPoint.self, from: json)

    XCTAssertEqual(point.x, -5.0)
    XCTAssertEqual(point.y, -10.0)
    XCTAssertEqual(point.label, "Negative")
  }
}
