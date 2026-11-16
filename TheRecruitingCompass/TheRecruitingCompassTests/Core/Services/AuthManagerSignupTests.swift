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
      dateOfBirth: "2011-05-01",
      captchaToken: "test-captcha-token"
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
        dateOfBirth: underThirteen,
        captchaToken: "test-captcha-token"
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

  // MARK: - beforePublish

  func testSignup_beforePublish_runsBeforeIsAuthenticatedPublishes() async throws {
    mockSupabaseManager.signUpResult = .success((user: userMock(), session: sessionMock()))
    var isAuthenticatedWhenHookRan: Bool?

    try await sut.signup(
      email: "player@example.com",
      password: "password123",
      fullName: "New Player",
      role: .player,
      familyCode: nil,
      captchaToken: "test-captcha-token",
      beforePublish: { [self] in
        isAuthenticatedWhenHookRan = self.sut.isAuthenticated
      }
    )

    XCTAssertEqual(isAuthenticatedWhenHookRan, false, "beforePublish must observe isAuthenticated still false")
    XCTAssertTrue(sut.isAuthenticated, "signup must still publish isAuthenticated once beforePublish completes")
  }

  func testSignup_beforePublish_notCalledWhenNoSessionReturned() async throws {
    mockSupabaseManager.signUpResult = .success((user: userMock(), session: nil))
    var hookCalled = false

    try await sut.signup(
      email: "player@example.com",
      password: "password123",
      fullName: "New Player",
      role: .player,
      familyCode: nil,
      captchaToken: "test-captcha-token",
      beforePublish: { hookCalled = true }
    )

    XCTAssertFalse(hookCalled, "email-confirmation signups have no session yet, so there's nothing to gate")
  }

  private func sessionMock() -> Session {
    Session(
      accessToken: "test-access-token",
      tokenType: "bearer",
      expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + 3600,
      refreshToken: "test-refresh-token",
      user: userMock()
    )
  }

  private func userMock() -> User {
    User(
      id: "user-1",
      email: "teen@example.com",
      emailConfirmedAt: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      role: .player
    )
  }

  // MARK: - parentSignupThisSession (ios#488: the signal that routes a new parent through first-run)

  private func signup(
    role: UserRole, skipVerificationEmail: Bool = false, withSession: Bool = true
  ) async throws {
    mockSupabaseManager.signUpResult = .success((user: userMock(), session: withSession ? sessionMock() : nil))
    try await sut.signup(
      email: "p@example.com", password: "password123", fullName: "Pat", role: role, familyCode: nil,
      captchaToken: "test-captcha-token", skipVerificationEmail: skipVerificationEmail
    )
  }

  func testSignup_ordinaryParent_isMarkedOrdinary() async throws {
    try await signup(role: .parent)
    XCTAssertEqual(sut.parentSignupThisSession, .ordinary)
  }

  func testSignup_inviteParent_isMarkedInvited() async throws {
    try await signup(role: .parent, skipVerificationEmail: true)
    XCTAssertEqual(sut.parentSignupThisSession, .invited)
  }

  func testSignup_player_isNeverMarked() async throws {
    try await signup(role: .player)
    XCTAssertNil(sut.parentSignupThisSession)
    try await signup(role: .player, skipVerificationEmail: true)
    XCTAssertNil(sut.parentSignupThisSession)
  }

  func testSignup_parentWithNoSession_isNotMarked() async throws {
    try await signup(role: .parent, withSession: false)
    XCTAssertNil(sut.parentSignupThisSession)
  }

  func testSignOut_clearsTheParentSignupSignal_soAnExistingParentIsNotSentToTheWizard() async throws {
    try await signup(role: .parent)
    XCTAssertEqual(sut.parentSignupThisSession, .ordinary)

    try await sut.logout()

    XCTAssertNil(sut.parentSignupThisSession)
  }

  func testSessionCleared_clearsTheParentSignupSignal() async throws {
    try await signup(role: .parent)
    mockSupabaseManager.currentSessionResult = nil

    await sut.restoreSession()

    XCTAssertFalse(sut.isAuthenticated)
    XCTAssertNil(sut.parentSignupThisSession)
  }

  func testSignup_whenSavingTheSessionFails_leavesNoSignalAndNoPublishedUser() async {
    struct SaveFailure: Error {}
    sut = AuthManager(
      supabaseManager: mockSupabaseManager, biometricService: mockBiometricService,
      accountProvisioning: MockAccountProvisioning(), persistSession: { _ in throw SaveFailure() }
    )
    mockSupabaseManager.signUpResult = .success((user: userMock(), session: sessionMock()))

    do {
      try await sut.signup(
        email: "p@example.com", password: "password123", fullName: "Pat", role: .parent, familyCode: nil,
        captchaToken: "test-captcha-token"
      )
      XCTFail("Expected the failed save to fail the signup")
    } catch {}

    XCTAssertNil(sut.parentSignupThisSession, "an existing parent logging in next must not be sent to first-run")
    XCTAssertNil(sut.user)
    XCTAssertNil(sut.session)
    XCTAssertFalse(sut.isAuthenticated)
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
