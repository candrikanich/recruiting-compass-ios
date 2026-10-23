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

  // Mirrors canonicalIds in web's tests/unit/components/Help/faqEntries.spec.ts; the canonical FAQ is web's
  // components/Help/faqEntries.ts. Same ids, same order.
  private let canonicalIds = [
    "cost",
    "availability",
    "web-vs-ios",
    "sports",
    "calendars",
    "templates",
    "recruiting-service",
    "family",
    "family-required",
    "privacy",
    "too-early",
    "different",
    "why-no-athletic-fit",
    "template-hidden",
    "task-locked",
    "share-document"
  ]

  func test_matchesCanonicalFaqIdsAndOrder() {
    XCTAssertEqual(FaqEntries.all.map(\.id), canonicalIds)
  }

  // Mirrors web faqEntries.ts `family` byte for byte (web#1398). Each family has one athlete.
  func test_familyEntryMatchesCanonicalCopy() {
    let family = FaqEntries.all.first { $0.id == "family" }
    XCTAssertEqual(
      family?.answer,
      "Yes. Parents and athletes join one family account — by email invite or Family Code — and see the same "
        + "schools, coaches, interactions, and timeline. Each family is built around one athlete; a parent with more "
        + "than one athlete joins each athlete's family and switches between them from the header."
    )
  }

  // Chris's 2026-10-23 decision: "Family Code" is a proper noun in all user-facing copy.
  func test_noFaqEntryUsesLowercaseFamilyCode() {
    for entry in FaqEntries.all {
      for text in [entry.question, entry.answer] {
        let withoutCanonical = text.replacingOccurrences(of: "Family Code", with: "")
        XCTAssertNil(
          withoutCanonical.range(of: "family code", options: .caseInsensitive),
          "FAQ '\(entry.id)' must spell it 'Family Code': \(text)"
        )
      }
    }
  }

  func test_familyRequiredEntryMatchesCanonicalJoinWording() {
    let answer = FaqEntries.all.first { $0.id == "family-required" }?.answer
    XCTAssertTrue(answer?.hasSuffix("or join with a Family Code.") ?? false, answer ?? "entry missing")
  }
}
