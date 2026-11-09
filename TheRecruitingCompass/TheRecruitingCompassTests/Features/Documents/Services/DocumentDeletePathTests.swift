import XCTest
@testable import TheRecruitingCompass

/// Which storage object `deleteDocument` removes for a row's `file_url`. Must never be an object that is not
/// the one the row points at (ios#527).
final class DocumentDeletePathTests: XCTestCase {
  nonisolated deinit {}

  private let origin = URL(string: "https://proj.supabase.co")!
  private let publicPrefix = "https://proj.supabase.co/storage/v1/object/public/documents/"

  private func path(_ raw: String) -> String? {
    DocumentsServiceImpl.storageObjectPath(forDeleting: raw, supabaseOrigin: origin)
  }

  func testUploadPlan_parentForAthlete_objectUnderParent_rowForAthlete_andDeleteResolvesIt() {
    let plan = DocumentsServiceImpl.uploadPlan(
      userId: "athlete-a", uploadedBy: "parent-p", familyUnitId: "family-1", type: .resume, timestamp: 5,
      fileName: "cv.pdf", mimeType: "application/pdf", title: "CV", description: nil, schoolId: nil, version: 2)
    let payload = plan.payload(fileUrl: plan.path)

    XCTAssertTrue(plan.path.hasPrefix("parent-p/"))
    XCTAssertEqual(payload.userId, "athlete-a")
    XCTAssertEqual(payload.uploadedBy, "parent-p")
    XCTAssertEqual(payload.familyUnitId, "family-1")
    XCTAssertEqual(path(plan.path), plan.path)
  }

  func testBarePath_isRemoved() {
    XCTAssertEqual(path("u1/resume/123_cv.pdf"), "u1/resume/123_cv.pdf")
  }

  func testOwnPublicURL_isRemovedByObjectPath() {
    XCTAssertEqual(path(publicPrefix + "u1/resume/1_my%20cv.pdf?t=1"), "u1/resume/1_my cv.pdf")
  }

  func testTraversal_isNeverUsedAsPath() {
    XCTAssertNil(path("../u2/resume/x.pdf"))
    XCTAssertNil(path("u1/%2e%2e/u2/x.pdf"))
    XCTAssertNil(path(publicPrefix + "u1/%2e%2e/u2/x.pdf"))
  }

  func testForeignURL_skipsStorageRemove() {
    XCTAssertNil(path("https://example.com/storage/v1/object/public/documents/u1/x.pdf"))
  }

  func testOtherSchemesAndEmpty_skipStorageRemove() {
    for raw in ["", "javascript:alert(1)", "file:///etc/passwd", "data:text/html,x"] {
      XCTAssertNil(path(raw), raw)
    }
  }

  func testForeignPathOnOwnOrigin_skipsStorageRemove() {
    XCTAssertNil(path("https://proj.supabase.co/storage/v1/object/public/avatars/u1/a.png"))
  }
}
