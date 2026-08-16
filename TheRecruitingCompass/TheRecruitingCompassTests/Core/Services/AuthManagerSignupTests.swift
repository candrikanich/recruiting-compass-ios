import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AuthManagerSignupTests: XCTestCase {
  nonisolated deinit {}
  var sut: AuthManager!
  var mockBiometricService: MockBiometricService!
  var mockSupabaseManager: MockSupabaseManager!

  override func setUp() {
    super.setUp()
    mockBiometricService = MockBiometricService()
    mockSupabaseManager = MockSupabaseManager()
    mockSupabaseManager.signUpResult = .success((user: userMock(), session: nil))
    sut = AuthManager(supabaseManager: mockSupabaseManager, biometricService: mockBiometricService)
  }

  override func tearDown() {
    sut = nil
    mockBiometricService = nil
    mockSupabaseManager = nil
    super.tearDown()
  }

  // MARK: - DOB persistence

  func testSignup_forwardsDateOfBirthToSupabase() async throws {
    try await sut.signup(
      email: "teen@example.com",
      password: "password123",
      fullName: "Rising Freshman",
      role: .player,
      familyCode: nil,
      dateOfBirth: "2011-05-01"
    )

    XCTAssertEqual(
      mockSupabaseManager.capturedSignUpDateOfBirth,
      "2011-05-01",
      "signup must forward DOB so users.date_of_birth is written (DB age trigger + cross-platform prefill)"
    )
  }

  func testSignup_underAgeDOB_blockedBeforeReachingSupabase() async {
    let underThirteen = ISO8601DateFormatter.yyyyMMdd(yearsAgo: 8)

    do {
      try await sut.signup(
        email: "kid@example.com",
        password: "password123",
        fullName: "Too Young",
        role: .player,
        familyCode: nil,
        dateOfBirth: underThirteen
      )
      XCTFail("Expected COPPA block")
    } catch {
      guard case AuthError.coppaUnderAge = error else {
        return XCTFail("Expected AuthError.coppaUnderAge, got \(error)")
      }
      XCTAssertNil(
        mockSupabaseManager.capturedSignUpDateOfBirth,
        "Under-13 signup must be blocked client-side before any Supabase write"
      )
    }
  }

  private func userMock() -> User {
    User(
      id: "user-1",
      email: "teen@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      role: .player
    )
  }
}

private extension ISO8601DateFormatter {
  /// "YYYY-MM-DD" for a date `yearsAgo` before now — builds an unambiguous under/over-age DOB.
  static func yyyyMMdd(yearsAgo: Int) -> String {
    let date = Calendar.current.date(byAdding: .year, value: -yearsAgo, to: Date.now) ?? Date.now
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f.string(from: date)
  }
}
