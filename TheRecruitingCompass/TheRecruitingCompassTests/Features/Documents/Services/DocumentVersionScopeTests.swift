import XCTest
@testable import TheRecruitingCompass

final class DocumentVersionScopeTests: XCTestCase {
  nonisolated deinit {}

  func testScope_documentWithFamily_listsVersionsByFamily() {
    var document = Document.mock(userId: "athlete-1")
    document.familyUnitId = "family-1"

    let scope = DocumentsServiceImpl.VersionScope(document: document)

    XCTAssertEqual(scope?.column, "family_unit_id")
    XCTAssertEqual(scope?.value, "family-1")
  }

  func testScope_documentWithoutFamily_fallsBackToUploader() {
    let scope = DocumentsServiceImpl.VersionScope(document: .mock(userId: "athlete-1"))

    XCTAssertEqual(scope?.column, "user_id")
    XCTAssertEqual(scope?.value, "athlete-1")
  }

  func testScope_documentWithNeither_hasNoScope() {
    var document = Document.mock(userId: "")
    document.familyUnitId = ""

    XCTAssertNil(DocumentsServiceImpl.VersionScope(document: document))
  }
}
