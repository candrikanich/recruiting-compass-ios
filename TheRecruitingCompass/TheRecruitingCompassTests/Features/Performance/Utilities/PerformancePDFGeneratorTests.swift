import XCTest
import PDFKit
@testable import TheRecruitingCompass

final class PerformancePDFGeneratorTests: XCTestCase {
  func testGeneratePDF_WithMetrics_ReturnsValidPDFData() async {
    // Given
    let metrics = [
      PerformanceMetric(
        id: "1",
        userId: "user1",
        metricType: .velocity,
        value: 85.5,
        unit: "mph",
        recordedDate: Date(),
        eventId: nil,
        verified: false,
        notes: "Test note",
        createdAt: Date(),
        updatedAt: Date()
      )
    ]
    let generator = PerformancePDFGenerator()

    // When
    let pdfData = await generator.generate(metrics: metrics, userName: "Test User")

    // Then
    XCTAssertNotNil(pdfData)
    XCTAssertGreaterThan(pdfData.count, 0)
  }

  func testGeneratePDF_WithEmptyMetrics_ReturnsValidPDFData() async {
    // Given
    let generator = PerformancePDFGenerator()

    // When
    let pdfData = await generator.generate(metrics: [], userName: "Test User")

    // Then
    XCTAssertNotNil(pdfData)
    XCTAssertGreaterThan(pdfData.count, 0)
  }

  func testPDF_ContainsAthleteNameAndMetricValues() async {
    // Given
    let generator = PerformancePDFGenerator()
    let metrics = [
      PerformanceMetric(
        id: "1",
        userId: "user1",
        metricType: .velocity,
        value: 85.5,
        unit: "mph",
        recordedDate: Date(),
        eventId: nil,
        verified: true,
        notes: nil,
        createdAt: Date(),
        updatedAt: Date()
      )
    ]

    // When
    let data = await generator.generate(metrics: metrics, userName: "Jane Doe")
    let pdf = PDFDocument(data: data)
    let pageText = pdf?.page(at: 0)?.string ?? ""

    // Then
    XCTAssertTrue(pageText.contains("Jane Doe"), "PDF should contain athlete name")
    XCTAssertTrue(pageText.contains("85.50 mph"), "PDF should contain formatted metric value")
    XCTAssertTrue(pageText.contains("Velocity"), "PDF should contain metric type")
  }

  func testPDF_SortsMetricsByDateDescending() async {
    // Given
    let generator = PerformancePDFGenerator()
    let now = Date()
    let dayAgo = now.addingTimeInterval(-86400)
    let twoDaysAgo = now.addingTimeInterval(-172800)

    let metrics = [
      PerformanceMetric(
        id: "1",
        userId: "user1",
        metricType: .velocity,
        value: 80.0,
        unit: "mph",
        recordedDate: twoDaysAgo,
        eventId: nil,
        verified: false,
        notes: nil,
        createdAt: twoDaysAgo,
        updatedAt: twoDaysAgo
      ),
      PerformanceMetric(
        id: "2",
        userId: "user1",
        metricType: .velocity,
        value: 85.0,
        unit: "mph",
        recordedDate: now,
        eventId: nil,
        verified: false,
        notes: nil,
        createdAt: now,
        updatedAt: now
      ),
      PerformanceMetric(
        id: "3",
        userId: "user1",
        metricType: .velocity,
        value: 82.5,
        unit: "mph",
        recordedDate: dayAgo,
        eventId: nil,
        verified: false,
        notes: nil,
        createdAt: dayAgo,
        updatedAt: dayAgo
      )
    ]

    // When
    let data = await generator.generate(metrics: metrics, userName: "Test User")
    let pdf = PDFDocument(data: data)
    let pageText = pdf?.page(at: 0)?.string ?? ""

    // Then
    XCTAssertNotNil(pdf, "Should generate valid PDF")
    let mostRecentIndex = pageText.range(of: "85.00 mph")
    let middleIndex = pageText.range(of: "82.50 mph")
    let oldestIndex = pageText.range(of: "80.00 mph")

    XCTAssertNotNil(mostRecentIndex, "Should contain most recent metric")
    XCTAssertNotNil(middleIndex, "Should contain middle metric")
    XCTAssertNotNil(oldestIndex, "Should contain oldest metric")

    if let recent = mostRecentIndex, let middle = middleIndex, let oldest = oldestIndex {
      XCTAssertLessThan(recent.lowerBound, middle.lowerBound, "Most recent should appear before middle")
      XCTAssertLessThan(middle.lowerBound, oldest.lowerBound, "Middle should appear before oldest")
    }
  }

  func testPDF_RespectsMaximumMetricLimit() async {
    // Given
    let generator = PerformancePDFGenerator()
    let metrics = (0..<60).map { index in
      PerformanceMetric(
        id: "\(index)",
        userId: "user1",
        metricType: .velocity,
        value: Double(index),
        unit: "mph",
        recordedDate: Date(),
        eventId: nil,
        verified: false,
        notes: nil,
        createdAt: Date(),
        updatedAt: Date()
      )
    }

    // When
    let data = await generator.generate(metrics: metrics, userName: "Test User")
    let pdf = PDFDocument(data: data)
    let pageText = pdf?.page(at: 0)?.string ?? ""

    // Then
    XCTAssertNotNil(pdf, "Should generate valid PDF")
    XCTAssertTrue(pageText.contains("Total Metrics Logged: 60"), "Should show total count")
    let hasTruncationIndicator = pageText.contains("and") && pageText.contains("more metric")
    XCTAssertTrue(hasTruncationIndicator, "Should show truncation indicator when metrics exceed limit")
  }

  func testPDF_WorksWithNilUserName() async {
    // Given
    let generator = PerformancePDFGenerator()
    let metrics = [
      PerformanceMetric(
        id: "1",
        userId: "user1",
        metricType: .velocity,
        value: 85.5,
        unit: "mph",
        recordedDate: Date(),
        eventId: nil,
        verified: false,
        notes: nil,
        createdAt: Date(),
        updatedAt: Date()
      )
    ]

    // When
    let data = await generator.generate(metrics: metrics, userName: nil)
    let pdf = PDFDocument(data: data)
    let pageText = pdf?.page(at: 0)?.string ?? ""

    // Then
    XCTAssertNotNil(pdf, "Should generate valid PDF with nil userName")
    XCTAssertTrue(pageText.contains("Performance Metrics Report"), "Should contain title")
    XCTAssertTrue(pageText.contains("85.50 mph"), "Should contain metric value")
    XCTAssertFalse(pageText.contains("Athlete:"), "Should not contain athlete label when userName is nil")
  }
}
