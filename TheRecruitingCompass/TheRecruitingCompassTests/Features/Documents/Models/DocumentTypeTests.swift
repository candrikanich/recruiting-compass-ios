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
    XCTAssertEqual(DocumentType.coachAttachment.typeEmoji, "📎")
    XCTAssertEqual(DocumentType.other.typeEmoji, "📁")
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
    XCTAssertEqual(DocumentType.coachAttachment.rawValue, "coach_attachment")
  }

  // MARK: - Lenient Decoding

  func testDecode_knownValue_decodesCorrectly() throws {
    let json = Data(#""coach_attachment""#.utf8)
    let decoded = try JSONDecoder().decode(DocumentType.self, from: json)
    XCTAssertEqual(decoded, .coachAttachment)
  }

  func testDecode_unknownValue_fallsBackToOther() throws {
    let json = Data(#""some_future_type""#.utf8)
    let decoded = try JSONDecoder().decode(DocumentType.self, from: json)
    XCTAssertEqual(decoded, .other)
  }

  func testDecode_emptyString_fallsBackToOther() throws {
    let json = Data(#""""#.utf8)
    let decoded = try JSONDecoder().decode(DocumentType.self, from: json)
    XCTAssertEqual(decoded, .other)
  }

  // MARK: - Uploadable Cases

  func testUploadableCases_excludesCoachAttachmentAndOther() {
    XCTAssertFalse(DocumentType.uploadableCases.contains(.coachAttachment))
    XCTAssertFalse(DocumentType.uploadableCases.contains(.other))
    XCTAssertTrue(DocumentType.uploadableCases.contains(.highlightVideo))
    XCTAssertTrue(DocumentType.uploadableCases.contains(.resume))
  }
}
