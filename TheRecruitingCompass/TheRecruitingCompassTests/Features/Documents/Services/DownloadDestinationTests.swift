import XCTest
@testable import TheRecruitingCompass

final class DownloadDestinationTests: XCTestCase {
  nonisolated deinit {}

  private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("dl-test", isDirectory: true)

  private func destination(_ title: String?, ext: String = "pdf") -> URL? {
    DownloadDestination.url(title: title, fallbackBase: "stored-name", pathExtension: ext, in: directory)
  }

  private func assertInside(_ url: URL?, file: StaticString = #filePath, line: UInt = #line) {
    guard let url else { return XCTFail("expected a destination", file: file, line: line) }
    XCTAssertEqual(url.standardizedFileURL.deletingLastPathComponent().path,
                   directory.standardizedFileURL.path, "\(url.path)", file: file, line: line)
  }

  func testPlainTitle_keepsNameAndExtension() {
    XCTAssertEqual(destination("My Resume")?.lastPathComponent, "My Resume.pdf")
  }

  func testTraversalTitles_cannotEscapeTheDirectory() {
    for title in ["../../x", "..", "a/../../b", "/etc/passwd", "..\\..\\x", "x/..", "a\u{0}b/../../c"] {
      assertInside(destination(title))
    }
  }

  func testSeparatorsAndControlCharacters_areStripped() {
    XCTAssertEqual(destination("dir/sub/Name")?.lastPathComponent, "Name.pdf")
    XCTAssertEqual(destination("a\r\nb\u{7F}")?.lastPathComponent, "ab.pdf")
  }

  func testEmptyAfterSanitizing_fallsBackToStoredNameThenUUID() {
    XCTAssertEqual(destination("../")?.lastPathComponent, "stored-name.pdf")
    let uuidNamed = DownloadDestination.url(title: "..", fallbackBase: "///", pathExtension: "", in: directory)
    assertInside(uuidNamed)
    XCTAssertNotNil(UUID(uuidString: uuidNamed?.lastPathComponent ?? ""))
  }

  func testHostileExtension_isReducedToAlphanumerics() {
    assertInside(destination("Doc", ext: "pdf/../../x"))
    XCTAssertEqual(destination("Doc", ext: "p/d")?.lastPathComponent, "Doc.pd")
  }
}
