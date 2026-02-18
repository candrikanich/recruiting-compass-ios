import XCTest
@testable import TheRecruitingCompass

@MainActor
final class DocumentTests: XCTestCase {

  func testIsShared_emptySchools_isFalse() {
    let doc = Document.mock(sharedWithSchools: [])
    XCTAssertFalse(doc.isShared)
  }

  func testIsShared_hasSchools_isTrue() {
    let doc = Document.mock(sharedWithSchools: ["school-1", "school-2"])
    XCTAssertTrue(doc.isShared)
  }

  func testTypeEmoji_delegatesToDocumentType() {
    XCTAssertEqual(Document.mock(type: .highlightVideo).typeEmoji, "🎥")
    XCTAssertEqual(Document.mock(type: .transcript).typeEmoji, "📄")
    XCTAssertEqual(Document.mock(type: .resume).typeEmoji, "📋")
  }

  func testDisplayDate_withValidISO8601_formatsAbbreviated() {
    let doc = Document.mock(createdAt: "2026-02-17T12:00:00Z")
    let result = doc.displayDate
    XCTAssertTrue(result.contains("Feb") || result.contains("2/17") || result.contains("17"))
    XCTAssertNotEqual(result, "Unknown")
  }

  func testDisplayDate_withNil_returnsUnknown() {
    let doc = Document.mock(createdAt: nil)
    XCTAssertEqual(doc.displayDate, "Unknown")
  }

  func testCodable_roundTrip_preservesData() throws {
    let doc = Document.mock(id: "d1", title: "My Video", type: .highlightVideo)
    let encoder = JSONEncoder()
    let data = try encoder.encode(doc)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(Document.self, from: data)
    XCTAssertEqual(decoded.id, doc.id)
    XCTAssertEqual(decoded.title, doc.title)
    XCTAssertEqual(decoded.type, doc.type)
  }
}
