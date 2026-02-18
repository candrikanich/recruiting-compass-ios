import XCTest
@testable import TheRecruitingCompass

final class DocumentTypeTests: XCTestCase {

  func testLabel_highlightVideo() {
    XCTAssertEqual(DocumentType.highlightVideo.label, "Highlight Video")
  }

  func testLabel_allCases_haveNonEmptyLabels() {
    for type in DocumentType.allCases {
      XCTAssertFalse(type.label.isEmpty, "\(type) should have a label")
    }
  }

  func testTypeEmoji_allCases_haveEmoji() {
    XCTAssertEqual(DocumentType.highlightVideo.typeEmoji, "🎥")
    XCTAssertEqual(DocumentType.transcript.typeEmoji, "📄")
    XCTAssertEqual(DocumentType.resume.typeEmoji, "📋")
    XCTAssertEqual(DocumentType.recLetter.typeEmoji, "💌")
    XCTAssertEqual(DocumentType.questionnaire.typeEmoji, "📝")
    XCTAssertEqual(DocumentType.statsSheet.typeEmoji, "📊")
  }

  func testAllowedExtensions_highlightVideo_includesVideoFormats() {
    let ext = DocumentType.highlightVideo.allowedExtensions
    XCTAssertTrue(ext.contains(".mp4"))
    XCTAssertTrue(ext.contains(".mov"))
    XCTAssertTrue(ext.contains(".avi"))
  }

  func testAllowedExtensions_transcript_includesPdfAndTxt() {
    let ext = DocumentType.transcript.allowedExtensions
    XCTAssertTrue(ext.contains(".pdf"))
    XCTAssertTrue(ext.contains(".txt"))
  }

  func testAllowedExtensions_resume_includesPdfAndDoc() {
    let ext = DocumentType.resume.allowedExtensions
    XCTAssertTrue(ext.contains(".pdf"))
    XCTAssertTrue(ext.contains(".doc"))
    XCTAssertTrue(ext.contains(".docx"))
  }

  func testRawValue_snake_case() {
    XCTAssertEqual(DocumentType.highlightVideo.rawValue, "highlight_video")
    XCTAssertEqual(DocumentType.statsSheet.rawValue, "stats_sheet")
  }
}
