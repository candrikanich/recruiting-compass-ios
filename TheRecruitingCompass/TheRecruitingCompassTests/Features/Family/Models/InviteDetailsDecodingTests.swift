import XCTest
@testable import TheRecruitingCompass

// Regression coverage for issue #903: InviteDetails required `email` and
// `inviterName` keys that the actual server response
// (server/api/family/invite/[token].get.ts) never sent — every real 200
// response from GET /api/family/invite/:token threw on decode, breaking the
// invite-join screen entirely. No decode test existed to catch this; these
// exercise the exact shape the server currently returns.
final class InviteDetailsDecodingTests: XCTestCase {
  func test_decodesTheServersActualResponseShape() throws {
    let json = """
    {
      "invitationId": "invite-abc",
      "role": "player",
      "familyName": "Smith Family",
      "invitedEmail": "player@example.com"
    }
    """.data(using: .utf8)!

    let details = try JSONDecoder().decode(InviteDetails.self, from: json)

    XCTAssertEqual(details.invitationId, "invite-abc")
    XCTAssertEqual(details.role, "player")
    XCTAssertEqual(details.familyName, "Smith Family")
    XCTAssertEqual(details.email, "player@example.com")
    XCTAssertNil(details.inviterName)
    XCTAssertFalse(details.emailExists)
    XCTAssertNil(details.prefill)
    XCTAssertNil(details.emailMismatch)
  }

  func test_decodesOptionalFieldsWhenServerDoesSendThem() throws {
    let json = """
    {
      "invitationId": "invite-abc",
      "role": "parent",
      "familyName": "Smith Family",
      "invitedEmail": "parent@example.com",
      "inviterName": "Alex Smith",
      "emailExists": true,
      "emailMismatch": false
    }
    """.data(using: .utf8)!

    let details = try JSONDecoder().decode(InviteDetails.self, from: json)

    XCTAssertEqual(details.inviterName, "Alex Smith")
    XCTAssertTrue(details.emailExists)
    XCTAssertEqual(details.emailMismatch, false)
  }
}
