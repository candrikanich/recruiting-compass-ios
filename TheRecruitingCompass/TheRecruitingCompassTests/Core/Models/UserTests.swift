import XCTest
@testable import TheRecruitingCompass

final class UserTests: XCTestCase {
  func testUserDecodingFromSupabaseResponse() throws {
    let json = """
    {
      "id": "12345678-1234-1234-1234-123456789012",
      "email": "user@example.com",
      "email_confirmed_at": "2024-01-15T10:30:00Z",
      "phone": null,
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-20T14:25:00Z"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let user = try decoder.decode(User.self, from: json)
    XCTAssertEqual(user.id, "12345678-1234-1234-1234-123456789012")
    XCTAssertEqual(user.email, "user@example.com")
    XCTAssertNotNil(user.emailConfirmedAt)
  }

  func testUserDecodesWithRole() throws {
    let json = """
    {
      "id": "123",
      "email": "test@example.com",
      "email_confirmed_at": "2024-01-01T00:00:00Z",
      "phone": null,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z",
      "role": "player"
    }
    """.data(using: .utf8)!

    let user = try JSONDecoder().decode(User.self, from: json)

    XCTAssertEqual(user.id, "123")
    XCTAssertEqual(user.email, "test@example.com")
    XCTAssertEqual(user.role, .player)
  }

  func testUserDecodesWithNullRole() throws {
    let json = """
    {
      "id": "123",
      "email": "test@example.com",
      "email_confirmed_at": null,
      "phone": null,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z",
      "role": null
    }
    """.data(using: .utf8)!

    let user = try JSONDecoder().decode(User.self, from: json)

    XCTAssertNil(user.role)
  }
}
