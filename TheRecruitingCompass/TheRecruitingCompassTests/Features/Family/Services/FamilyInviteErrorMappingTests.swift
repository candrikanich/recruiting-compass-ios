import XCTest
@testable import TheRecruitingCompass

// Messages mirror web's server/api/family/invite/[token]/accept.post.ts (shown by join.vue).
final class FamilyInviteErrorMappingTests: XCTestCase {
  nonisolated deinit {}

  private func body(_ message: String, status: Int) -> Data {
    Data(#"{"statusCode":\#(status),"statusMessage":"\#(message)"}"#.utf8)
  }

  private func assertAcceptMessage(status: Int, message: String, file: StaticString = #filePath, line: UInt = #line) {
    let error = FamilyServiceImpl.acceptInviteFailure(data: body(message, status: status), statusCode: status)
    XCTAssertEqual(error.errorDescription, message, file: file, line: line)
  }

  func testAcceptFailure_403_surfacesServerMessage() {
    assertAcceptMessage(status: 403, message: "This invitation was sent to a different email address")
  }

  func testAcceptFailure_409_surfacesServerMessage() {
    assertAcceptMessage(status: 409, message: "Invitation is no longer valid")
  }

  func testAcceptFailure_409_familyAlreadyHasPlayer_surfacesServerMessage() {
    assertAcceptMessage(status: 409, message: "This family already has a player")
  }

  func testAcceptFailure_410_surfacesServerMessage() {
    assertAcceptMessage(status: 410, message: "This invitation has expired")
  }

  func testAcceptFailure_withoutBody_usesAcceptFallback() {
    let error = FamilyServiceImpl.acceptInviteFailure(data: Data(), statusCode: 502)
    XCTAssertEqual(error.errorDescription, "Failed to accept invite (status 502)")
  }

  func testServerErrorMessage_withoutBody_keepsSendFallback() {
    XCTAssertEqual(
      FamilyServiceImpl.serverErrorMessage(from: Data(), statusCode: 500),
      "Failed to send invite (status 500)"
    )
  }
}
