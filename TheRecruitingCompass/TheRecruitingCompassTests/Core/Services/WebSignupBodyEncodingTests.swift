import XCTest
@testable import TheRecruitingCompass

final class WebSignupBodyEncodingTests: XCTestCase {
  private func makeBody(marketingEmailOptIn: Bool?) -> WebSignupBody {
    WebSignupBody(
      email: "a@example.com",
      password: "StrongPass123",
      fullName: "A B",
      role: "parent",
      dateOfBirth: nil,
      captchaToken: "tok",
      metadata: [:],
      skipVerificationEmail: false,
      marketingEmailOptIn: marketingEmailOptIn
    )
  }

  private func encodedObject(_ body: WebSignupBody) throws -> [String: Any] {
    let data = try JSONEncoder().encode(body)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  func test_encodes_marketingEmailOptIn_true() throws {
    let json = try encodedObject(makeBody(marketingEmailOptIn: true))
    XCTAssertEqual(json["marketingEmailOptIn"] as? Bool, true)
  }

  func test_encodes_marketingEmailOptIn_false() throws {
    let json = try encodedObject(makeBody(marketingEmailOptIn: false))
    XCTAssertEqual(json["marketingEmailOptIn"] as? Bool, false)
  }

  func test_omits_marketingEmailOptIn_whenNil() throws {
    let json = try encodedObject(makeBody(marketingEmailOptIn: nil))
    XCTAssertNil(json["marketingEmailOptIn"])
    XCTAssertEqual(json["email"] as? String, "a@example.com")
  }
}
