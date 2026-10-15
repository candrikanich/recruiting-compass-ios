import XCTest
@testable import TheRecruitingCompass

final class FamilyLabelTests: XCTestCase {
  func test_display_prefersServerLabel() {
    XCTAssertEqual(FamilyLabel.display(label: "Alex's Family", legacyName: "Smith Family"), "Alex's Family")
  }

  func test_display_fallsBackToLegacyNameWhenLabelAbsentOrBlank() {
    XCTAssertEqual(FamilyLabel.display(label: nil, legacyName: "Smith Family"), "Smith Family")
    XCTAssertEqual(FamilyLabel.display(label: "  ", legacyName: "Smith Family"), "Smith Family")
  }

  func test_display_nilWhenNothingKnown() {
    XCTAssertNil(FamilyLabel.display(label: nil, legacyName: nil))
  }

  func test_inviteDetails_decodesFamilyLabel() throws {
    let json = Data("""
    {"invitationId":"i","role":"player","familyName":"Smith Family","familyLabel":"Alex's Family",
     "invitedEmail":"p@example.com"}
    """.utf8)
    let details = try JSONDecoder().decode(InviteDetails.self, from: json)
    XCTAssertEqual(details.familyLabel, "Alex's Family")
    XCTAssertEqual(details.displayLabel, "Alex's Family")
    XCTAssertEqual(details.headline, "Join Alex's Family")
  }

  func test_inviteDetails_withoutFamilyLabel_keepsLegacyCopy() throws {
    let json = Data("""
    {"invitationId":"i","role":"player","familyName":"Smith Family","invitedEmail":"p@example.com"}
    """.utf8)
    let details = try JSONDecoder().decode(InviteDetails.self, from: json)
    XCTAssertNil(details.familyLabel)
    XCTAssertEqual(details.displayLabel, "Smith Family")
    XCTAssertEqual(details.headline, "Smith Family's recruiting journey")
  }

  func test_inboundAddress_decodesWithAndWithoutFamilyLabel() throws {
    let withLabel = Data("""
    {"addresses":[{"familyUnitId":"f1","familyName":"Smith Family","familyLabel":"Alex's Family","address":"a@b.c"}]}
    """.utf8)
    let without = Data("""
    {"addresses":[{"familyUnitId":"f1","familyName":"Smith Family","address":"a@b.c"}]}
    """.utf8)
    let decoder = JSONDecoder()
    XCTAssertEqual(try decoder.decode(InboundAddressResponse.self, from: withLabel).addresses[0].displayLabel,
                   "Alex's Family")
    XCTAssertEqual(try decoder.decode(InboundAddressResponse.self, from: without).addresses[0].displayLabel,
                   "Smith Family")
  }

  func test_joinResponse_decodesWithAndWithoutLabel() throws {
    let decoder = JSONDecoder()
    let withLabel = Data(#"{"success":true,"familyId":"f1","familyName":"S","familyLabel":"Alex's Family"}"#.utf8)
    let without = Data(#"{"success":true,"familyId":"f1","familyName":"Smith Family"}"#.utf8)
    XCTAssertEqual(try decoder.decode(JoinFamilyResponse.self, from: withLabel).displayLabel, "Alex's Family")
    XCTAssertEqual(try decoder.decode(JoinFamilyResponse.self, from: without).displayLabel, "Smith Family")
  }
}
