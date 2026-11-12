import XCTest
@testable import TheRecruitingCompass

/// Storage keys reject characters like `|` ("Invalid key", ios#576). The key is sanitized; the title the user
/// sees is not. Rules mirror web#1709: keep [A-Za-z0-9._-], everything else becomes `_`, extension kept,
/// base capped at 100 chars, extension at 10.
final class DocumentUploadKeyTests: XCTestCase {
  nonisolated deinit {}

  private func plan(
    _ fileName: String, uploadedBy: String = "parent-p", timestamp: Int = 7
  ) -> DocumentsServiceImpl.UploadPlan {
    DocumentsServiceImpl.uploadPlan(
      userId: "athlete-a", uploadedBy: uploadedBy, familyUnitId: nil, type: .resume, timestamp: timestamp,
      fileName: fileName, mimeType: "application/pdf", title: fileName, description: nil, schoolId: nil, version: 1)
  }

  func testPipe_isReplaced() {
    XCTAssertEqual(plan("a|b.pdf").path, "parent-p/resume/7_a_b.pdf")
  }

  func testHashAndQuestionMark_areReplaced() {
    XCTAssertEqual(plan("c#1?.pdf").path, "parent-p/resume/7_c_1_.pdf")
  }

  func testEmojiAndAccents_areReplaced() {
    XCTAssertEqual(plan("résumé 🎉.pdf").path, "parent-p/resume/7_r_sum___.pdf")
  }

  func testSafeCharacters_areKept() {
    XCTAssertEqual(plan("My-CV_v2.final.PDF").path, "parent-p/resume/7_My-CV_v2.final.PDF")
  }

  func testLongName_isCappedAndKeepsExtension() {
    let path = plan(String(repeating: "a", count: 300) + ".pdf").path
    XCTAssertEqual(path, "parent-p/resume/7_" + String(repeating: "a", count: 100) + ".pdf")
  }

  func testNoExtension_andEmptyBase() {
    XCTAssertEqual(plan("notes").path, "parent-p/resume/7_notes")
    XCTAssertEqual(plan("|.pdf").path, "parent-p/resume/7__.pdf")
    XCTAssertEqual(plan("").path, "parent-p/resume/7_file")
  }

  func testFirstFolderStaysUploadedBy_andTimestampKeepsKeysDistinct() {
    XCTAssertTrue(plan("a|b.pdf").path.hasPrefix("parent-p/"))
    XCTAssertNotEqual(plan("a|b.pdf", timestamp: 1).path, plan("a_b.pdf", timestamp: 2).path)
  }

  func testUserVisibleTitle_isUntouched() {
    XCTAssertEqual(plan("a|b.pdf").payload(fileUrl: "x").title, "a|b.pdf")
  }
}
