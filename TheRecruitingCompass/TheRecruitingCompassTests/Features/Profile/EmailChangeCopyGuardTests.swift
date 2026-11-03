import XCTest
@testable import TheRecruitingCompass

/// The single-inbox wording must not return anywhere in the app: with Secure email change on, it leaves a change
/// half-done (ios#498).
final class EmailChangeCopyGuardTests: XCTestCase {
  private static var sourceRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("TheRecruitingCompass")
  }

  private static let retiredPhrases = [
    "A verification email has been sent to your new address",
    "Check your inbox to confirm the change",
    "Verification email sent. Check your inbox."
  ]

  func test_noAppSourceContainsRetiredEmailChangeCopy() throws {
    let files = try XCTUnwrap(
      FileManager.default.enumerator(at: Self.sourceRoot, includingPropertiesForKeys: nil)
    ).compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    XCTAssertFalse(files.isEmpty, "source root not found: \(Self.sourceRoot.path)")

    var offenders: [String] = []
    for file in files {
      let text = try String(contentsOf: file, encoding: .utf8)
      for phrase in Self.retiredPhrases where text.contains(phrase) {
        offenders.append("\(file.lastPathComponent): \(phrase)")
      }
    }
    XCTAssertEqual(offenders, [])
  }
}
