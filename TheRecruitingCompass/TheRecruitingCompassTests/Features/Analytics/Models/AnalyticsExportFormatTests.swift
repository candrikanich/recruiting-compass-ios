import XCTest
@testable import TheRecruitingCompass

final class AnalyticsExportFormatTests: XCTestCase {

  // MARK: - Raw Value Tests

  func testRawValues() {
    XCTAssertEqual(AnalyticsExportFormat.csv.rawValue, "csv")
    XCTAssertEqual(AnalyticsExportFormat.excel.rawValue, "excel")
    XCTAssertEqual(AnalyticsExportFormat.pdf.rawValue, "pdf")
  }

  // MARK: - Identifiable Tests

  func testIdentifiable_IdMatchesRawValue() {
    for format in AnalyticsExportFormat.allCases {
      XCTAssertEqual(format.id, format.rawValue)
    }
  }

  // MARK: - CaseIterable Tests

  func testCaseIterable_ContainsThreeCases() {
    XCTAssertEqual(AnalyticsExportFormat.allCases.count, 3)
  }

  func testCaseIterable_ContainsExpectedCases() {
    let allCases = AnalyticsExportFormat.allCases
    XCTAssertTrue(allCases.contains(.csv))
    XCTAssertTrue(allCases.contains(.excel))
    XCTAssertTrue(allCases.contains(.pdf))
  }

  // MARK: - Display Name Tests

  func testDisplayNames() {
    XCTAssertEqual(AnalyticsExportFormat.csv.displayName, "CSV")
    XCTAssertEqual(AnalyticsExportFormat.excel.displayName, "Excel")
    XCTAssertEqual(AnalyticsExportFormat.pdf.displayName, "PDF")
  }

  // MARK: - File Extension Tests

  func testFileExtensions() {
    XCTAssertEqual(AnalyticsExportFormat.csv.fileExtension, "csv")
    XCTAssertEqual(AnalyticsExportFormat.excel.fileExtension, "xlsx")
    XCTAssertEqual(AnalyticsExportFormat.pdf.fileExtension, "pdf")
  }

  // MARK: - MIME Type Tests

  func testMimeTypes() {
    XCTAssertEqual(AnalyticsExportFormat.csv.mimeType, "text/csv")
    XCTAssertEqual(AnalyticsExportFormat.excel.mimeType, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    XCTAssertEqual(AnalyticsExportFormat.pdf.mimeType, "application/pdf")
  }

  // MARK: - Icon Name Tests

  func testIconNames() {
    XCTAssertEqual(AnalyticsExportFormat.csv.iconName, "tablecells")
    XCTAssertEqual(AnalyticsExportFormat.excel.iconName, "tablecells.fill")
    XCTAssertEqual(AnalyticsExportFormat.pdf.iconName, "doc.richtext")
  }

  func testAllFormats_HaveNonEmptyIconNames() {
    for format in AnalyticsExportFormat.allCases {
      XCTAssertFalse(format.iconName.isEmpty, "\(format.rawValue) should have a non-empty icon name")
    }
  }
}
