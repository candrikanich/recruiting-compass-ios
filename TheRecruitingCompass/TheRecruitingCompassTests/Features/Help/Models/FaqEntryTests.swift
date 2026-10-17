import XCTest
@testable import TheRecruitingCompass

final class FaqEntryTests: XCTestCase {
  // App Review 3.1.1: 1.0 has no in-app purchase, so the app must not quote prices for plans it can't sell.
  // Apple's 2026-10-16 rejection asked to "ensure paid plans are available to purchase" — a price in the FAQ
  // invites exactly that reading.
  func test_noFaqEntryQuotesAPrice() {
    let pricePattern = try! NSRegularExpression(pattern: #"\$\s?\d|/\s?(year|yr|month|mo)\b"#, options: .caseInsensitive)
    for entry in FaqEntries.all {
      for text in [entry.question, entry.answer] {
        let range = NSRange(text.startIndex..., in: text)
        XCTAssertNil(
          pricePattern.firstMatch(in: text, range: range),
          "FAQ '\(entry.id)' quotes a price: \(text)"
        )
      }
    }
  }
}
