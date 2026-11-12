import XCTest
@testable import TheRecruitingCompass

/// Storage keys reject characters like `|` ("Invalid key", ios#576). The key is sanitized; the title the user
/// sees is not. Web (web#1709) mirrors the shared vectors:
/// see StorageKey.safeFileName for the rule.
final class DocumentUploadKeyTests: XCTestCase {
  nonisolated deinit {}

  private func plan(
    _ fileName: String, uploadedBy: String = "parent-p", timestamp: Int = 7
  ) -> DocumentsServiceImpl.UploadPlan {
    DocumentsServiceImpl.uploadPlan(
      userId: "athlete-a", uploadedBy: uploadedBy, familyUnitId: nil, type: .resume, timestamp: timestamp,
      fileName: fileName, mimeType: "application/pdf", title: fileName, description: nil, schoolId: nil, version: 1)
  }

  private func safe(_ name: String) -> String { StorageKey.safeFileName(name) }

  func testSharedVectors_matchWeb() {
    XCTAssertEqual(safe("Bulldogs at Firelands | Scorebook | GameChanger.pdf"),
                   "Bulldogs_at_Firelands_Scorebook_GameChanger.pdf")
    XCTAssertEqual(safe("résumé 🎉.pdf"), "r_sum_.pdf")
    XCTAssertEqual(safe("Rene\u{301}e.pdf"), "Ren_e.pdf")
    XCTAssertEqual(safe("👨‍👩‍👧.pdf"), "file.pdf")
    XCTAssertEqual(safe("履歴書.pdf"), "file.pdf")
    XCTAssertEqual(safe("🎉"), "file")
    XCTAssertEqual(safe("a." + String(repeating: "b", count: 30)), "a.bbbbbbbbbb")
    XCTAssertEqual(safe("report.2024.final.pdf"), "report.2024.final.pdf")
    XCTAssertEqual(safe(String(repeating: "a", count: 300) + ".pdf"), String(repeating: "a", count: 100) + ".pdf")
  }

  func testPipe_hashAndQuestionMark_areReplaced() {
    XCTAssertEqual(plan("a|b.pdf").path, "parent-p/resume/7_a_b.pdf")
    XCTAssertEqual(plan("c#1?.pdf").path, "parent-p/resume/7_c_1_.pdf")
  }

  func testSafeCharacters_areKept() {
    XCTAssertEqual(plan("My-CV_v2.final.PDF").path, "parent-p/resume/7_My-CV_v2.final.PDF")
  }

  func testNoExtension_andEmptyOrUnderscoreBase() {
    XCTAssertEqual(safe("notes"), "notes")
    XCTAssertEqual(safe("|.pdf"), "file.pdf")
    XCTAssertEqual(safe(""), "file")
  }

  func testRunsCollapseBeforeTheCap() {
    let name = "a" + String(repeating: "|", count: 200) + String(repeating: "b", count: 200)
    XCTAssertEqual(safe(name), "a_" + String(repeating: "b", count: 98))
  }

  func testFirstFolderStaysUploadedBy() {
    XCTAssertTrue(plan("a|b.pdf").path.hasPrefix("parent-p/"))
  }

  func testSameNameAtDifferentTimestamps_givesDifferentKeys() {
    XCTAssertNotEqual(plan("a|b.pdf", timestamp: 1).path, plan("a|b.pdf", timestamp: 2).path)
  }

  func testUserVisibleTitle_isUntouched() {
    XCTAssertEqual(plan("a|b.pdf").payload(fileUrl: "x").title, "a|b.pdf")
  }
}
