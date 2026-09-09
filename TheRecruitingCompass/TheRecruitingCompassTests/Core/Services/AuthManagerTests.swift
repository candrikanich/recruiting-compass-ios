import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AuthManagerTests: XCTestCase {
  nonisolated deinit {}
  var sut: AuthManager!
  var mockSupabaseManager: MockSupabaseManager!

  override func setUp() {
    super.setUp()
    mockSupabaseManager = MockSupabaseManager()
    sut = AuthManager(supabaseManager: mockSupabaseManager)
  }

  override func tearDown() {
    sut = nil
    mockSupabaseManager = nil
    super.tearDown()
  }

  func testLoginForwardsCaptchaToken() async throws {
    let user = User(
      id: "test-user-id", email: "user@example.com", emailConfirmedAt: nil, phone: nil,
      fullName: nil, createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z",
      role: nil, dateOfBirth: nil
    )
    let session = Session(
      accessToken: "token", tokenType: "bearer", expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + 3600, refreshToken: "refresh", user: user
    )
    mockSupabaseManager.signInResult = .success((user: user, session: session))

    try await sut.login(email: "user@example.com", password: "password123", captchaToken: "test-captcha-token")

    XCTAssertEqual(mockSupabaseManager.capturedSignInCaptchaToken, "test-captcha-token")
  }

  func testSignupForwardsCaptchaToken() async throws {
    let user = User(
      id: "test-user-id", email: "user@example.com", emailConfirmedAt: nil, phone: nil,
      fullName: "Jane Doe", createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z",
      role: .player, dateOfBirth: nil
    )
    mockSupabaseManager.signUpResult = .success((user: user, session: nil))

    try await sut.signup(
      email: "user@example.com",
      password: "password123",
      fullName: "Jane Doe",
      role: .player,
      familyCode: nil,
      dateOfBirth: "2005-01-01",
      captchaToken: "test-captcha-token"
    )

    XCTAssertEqual(mockSupabaseManager.capturedSignUpCaptchaToken, "test-captcha-token")
  }

  func testResetPasswordForEmailForwardsCaptchaToken() async throws {
    try await sut.resetPasswordForEmail(email: "user@example.com", captchaToken: "test-captcha-token")

    XCTAssertEqual(mockSupabaseManager.capturedResetPasswordCaptchaToken, "test-captcha-token")
  }
}
