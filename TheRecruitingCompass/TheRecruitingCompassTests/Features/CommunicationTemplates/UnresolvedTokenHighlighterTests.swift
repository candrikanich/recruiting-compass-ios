import SwiftUI
import XCTest
@testable import TheRecruitingCompass

final class UnresolvedTokenHighlighterTests: XCTestCase {
  func test_plainTextRoundTripsUnchanged() {
    let a = UnresolvedTokenHighlighter.attributed("Hi Coach Smith", tokenColor: .orange)
    XCTAssertEqual(String(a.characters), "Hi Coach Smith")
  }

  func test_tokenRunsAreColored() {
    let a = UnresolvedTokenHighlighter.attributed("Hi {{programNote}} bye", tokenColor: .orange)
    XCTAssertEqual(String(a.characters), "Hi {{programNote}} bye")
    // Exactly one colored run, and it is the token substring.
    let colored = a.runs.filter { $0.foregroundColor == .orange }
    XCTAssertEqual(colored.count, 1)
    let coloredText = colored.map { String(a[$0.range].characters) }.joined()
    XCTAssertEqual(coloredText, "{{programNote}}")
  }

  func test_multipleTokens() {
    let a = UnresolvedTokenHighlighter.attributed("{{a}} x {{b}}", tokenColor: .orange)
    let colored = a.runs.filter { $0.foregroundColor == .orange }
                        .map { String(a[$0.range].characters) }
    XCTAssertEqual(colored, ["{{a}}", "{{b}}"])
  }
}
