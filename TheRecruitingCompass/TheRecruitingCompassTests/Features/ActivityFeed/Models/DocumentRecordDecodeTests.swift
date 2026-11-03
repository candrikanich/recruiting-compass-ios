import XCTest
@testable import TheRecruitingCompass

final class DocumentRecordDecodeTests: XCTestCase {
  func testDecode_creditsUploadedBy_notTheOwnerUserId() throws {
    let json = Data("""
    {"id":"d1","title":"T","type":"pdf","created_at":"2026-02-10T10:00:00Z",
     "uploaded_by":"uploader-parent","user_id":"owner-athlete"}
    """.utf8)

    let record = try JSONDecoder().decode(DocumentRecord.self, from: json)

    XCTAssertEqual(record.uploadedBy, "uploader-parent")
  }

  func testDecode_nullUploadedBy_isNil() throws {
    let json = Data("""
    {"id":"d1","title":"T","type":null,"created_at":"2026-02-10T10:00:00Z",
     "uploaded_by":null,"user_id":"owner-athlete"}
    """.utf8)

    XCTAssertNil(try JSONDecoder().decode(DocumentRecord.self, from: json).uploadedBy)
  }
}
