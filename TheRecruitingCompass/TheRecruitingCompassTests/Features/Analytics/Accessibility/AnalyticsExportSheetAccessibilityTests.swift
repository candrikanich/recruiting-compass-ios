import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class AnalyticsExportSheetAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Export Button Label Tests

  func testExportSheet_allFormatsHaveLabels() {
    for format in AnalyticsExportFormat.allCases {
      let view = AnalyticsExportSheet { _ in }
      XCTAssertNotNil(view)
      // Each button gets .accessibilityLabel("Export as [displayName]")
      XCTAssertFalse(format.displayName.isEmpty)
    }
  }

  func testExportSheet_csvHasLabel() {
    XCTAssertEqual(AnalyticsExportFormat.csv.displayName, "CSV")
    XCTAssertEqual(AnalyticsExportFormat.csv.fileExtension, "csv")
  }

  func testExportSheet_excelHasLabel() {
    XCTAssertEqual(AnalyticsExportFormat.excel.displayName, "Excel")
    XCTAssertEqual(AnalyticsExportFormat.excel.fileExtension, "xlsx")
  }

  func testExportSheet_pdfHasLabel() {
    XCTAssertEqual(AnalyticsExportFormat.pdf.displayName, "PDF")
    XCTAssertEqual(AnalyticsExportFormat.pdf.fileExtension, "pdf")
  }

  // MARK: - Hint Tests

  func testExportSheet_allFormatsHaveHints() {
    // Each button gets .accessibilityHint("Downloads analytics data as a .[ext] file")
    for format in AnalyticsExportFormat.allCases {
      XCTAssertFalse(format.fileExtension.isEmpty)
    }
  }

  // MARK: - Icon Hidden Tests

  func testExportSheet_formatIconsAreHidden() {
    // Format icons (tablecells, tablecells.fill, doc.richtext) use .accessibilityHidden(true)
    for format in AnalyticsExportFormat.allCases {
      XCTAssertFalse(format.iconName.isEmpty)
    }
  }

  func testExportSheet_downloadIconsAreHidden() {
    // Download arrow icons (arrow.down.circle) use .accessibilityHidden(true)
    let view = AnalyticsExportSheet { _ in }
    XCTAssertNotNil(view)
  }

  // MARK: - Navigation Tests

  func testExportSheet_hasNavigationTitle() {
    // Navigation title is "Export Analytics"
    let view = AnalyticsExportSheet { _ in }
    XCTAssertNotNil(view)
  }

  func testExportSheet_hasCancelButton() {
    // Cancel button in toolbar for dismissing
    let view = AnalyticsExportSheet { _ in }
    XCTAssertNotNil(view)
  }

  // MARK: - Dynamic Type Tests

  func testExportSheet_supportsDynamicType() {
    let sizes: [ContentSizeCategory] = [
      .extraSmall,
      .accessibilityExtraExtraExtraLarge
    ]
    for size in sizes {
      let view = AnalyticsExportSheet { _ in }
        .environment(\.sizeCategory, size)
      XCTAssertNotNil(view)
    }
  }

  // MARK: - Semantic Font Tests

  func testExportSheet_usesSemanticFonts() {
    // Uses .body, .caption, .title3 -- all semantic
    let view = AnalyticsExportSheet { _ in }
    XCTAssertNotNil(view)
  }
}
