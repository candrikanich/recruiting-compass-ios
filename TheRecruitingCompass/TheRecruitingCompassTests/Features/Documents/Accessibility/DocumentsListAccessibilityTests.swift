import XCTest
@testable import TheRecruitingCompass

/// Verifies Documents List accessibility: sort/filter labels and document type display names.
@MainActor
final class DocumentsListAccessibilityTests: XCTestCase {

  // MARK: - Sort option labels (used in sort menu accessibility)

  func testSortOption_newest_hasLabel() {
    XCTAssertEqual(DocumentSortOption.newest.label, "Newest First")
  }

  func testSortOption_oldest_hasLabel() {
    XCTAssertEqual(DocumentSortOption.oldest.label, "Oldest First")
  }

  func testSortOption_name_hasLabel() {
    XCTAssertEqual(DocumentSortOption.name.label, "Name (A-Z)")
  }

  func testSortOption_type_hasLabel() {
    XCTAssertEqual(DocumentSortOption.type.label, "Type")
  }

  func testSortOption_shared_hasLabel() {
    XCTAssertEqual(DocumentSortOption.shared.label, "Most Shared")
  }

  // MARK: - Document type labels (used in cards and filters)

  func testDocumentType_highlightVideo_hasLabel() {
    XCTAssertEqual(DocumentType.highlightVideo.label, "Highlight Video")
  }

  func testDocumentType_transcript_hasLabel() {
    XCTAssertEqual(DocumentType.transcript.label, "Transcript")
  }

  func testDocumentType_resume_hasLabel() {
    XCTAssertEqual(DocumentType.resume.label, "Resume")
  }

  func testDocumentType_allCases_haveNonEmptyLabels() {
    for type in DocumentType.allCases {
      XCTAssertFalse(type.label.isEmpty, "\(type) should have accessibility label")
    }
  }
}
