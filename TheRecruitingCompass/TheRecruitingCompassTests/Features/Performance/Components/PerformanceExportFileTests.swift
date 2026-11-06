import XCTest
@testable import TheRecruitingCompass

/// The file handed to the system share sheet when exporting performance metrics (#252).
final class PerformanceExportFileTests: XCTestCase {
  private var directory: URL!

  override func setUpWithError() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: directory)
  }

  func test_filename_csv_usesDateAndLowercaseExtension() throws {
    let date = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 12)))

    XCTAssertEqual(ExportFormat.csv.filename(on: date), "performance_metrics_2026-10-02.csv")
  }

  func test_filename_pdf_usesPdfExtension() throws {
    let date = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 12)))

    XCTAssertEqual(ExportFormat.pdf.filename(on: date), "performance_metrics_2026-01-05.pdf")
  }

  func test_write_createsTheFileWithTheData() throws {
    let data = Data("metric,value\n60yd,6.8".utf8)

    let file = try PerformanceExportFile.write(data, named: "performance_metrics_2026-10-02.csv", in: directory)

    XCTAssertEqual(file.url.lastPathComponent, "performance_metrics_2026-10-02.csv")
    XCTAssertEqual(try Data(contentsOf: file.url), data)
  }

  func test_write_replacesAnEarlierExportWithTheSameName() throws {
    _ = try PerformanceExportFile.write(Data("old".utf8), named: "export.csv", in: directory)

    let file = try PerformanceExportFile.write(Data("new".utf8), named: "export.csv", in: directory)

    XCTAssertEqual(try String(contentsOf: file.url, encoding: .utf8), "new")
  }

  func test_write_toAMissingDirectory_throws() {
    let missing = directory.appendingPathComponent("does-not-exist")

    XCTAssertThrowsError(try PerformanceExportFile.write(Data("x".utf8), named: "export.csv", in: missing))
  }
}
