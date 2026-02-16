import XCTest
@testable import TheRecruitingCompass

final class PerformancePDFGeneratorTests: XCTestCase {
  func testGeneratePDF_WithMetrics_ReturnsValidPDFData() {
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
    let pdfData = generator.generate(metrics: metrics, userName: "Test User")

    // Then
    XCTAssertNotNil(pdfData)
    XCTAssertGreaterThan(pdfData.count, 0)
  }

  func testGeneratePDF_WithEmptyMetrics_ReturnsValidPDFData() {
    // Given
    let generator = PerformancePDFGenerator()

    // When
    let pdfData = generator.generate(metrics: [], userName: "Test User")

    // Then
    XCTAssertNotNil(pdfData)
    XCTAssertGreaterThan(pdfData.count, 0)
  }
}
