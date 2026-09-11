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
    // Must be 18+: a 13-17 DOB is blocked client-side before any Supabase call, so a
    // minor DOB here would assert nothing about forwarding. Relative, not hardcoded —
    // a fixed date silently ages into the minor band and breaks this test later.
    let adult = ISO8601DateFormatter.yyyyMMdd(yearsAgo: 20)

    try await sut.signup(
      email: "player@example.com",
      password: "password123",
      fullName: "Adult Player",
      role: .player,
      familyCode: nil,
      dateOfBirth: adult,
      captchaToken: "test-captcha-token"
    )

    XCTAssertEqual(
      mockSupabaseManager.capturedSignUpDateOfBirth,
      adult,
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

  // MARK: - Minor (13-17) guardian-invite guard

  func testSignup_minorPlayer_blockedBeforeReachingSupabase() async {
    let fifteen = ISO8601DateFormatter.yyyyMMdd(yearsAgo: 15)

    do {
      try await sut.signup(
        email: "minor@example.com",
        password: "password123",
        fullName: "Minor Player",
        role: .player,
        familyCode: nil,
        dateOfBirth: fifteen,
        captchaToken: "test-captcha-token"
      )
      XCTFail("Expected minor signup to be blocked")
    } catch {
      guard case AuthError.minorRequiresGuardianInvite = error else {
        return XCTFail("Expected AuthError.minorRequiresGuardianInvite, got \(error)")
      }
      // The regression this guards: `SupabaseManager.signUp` creates the auth user and
      // only then upserts `public.users`, where the DB trigger rejects a minor. Reaching
      // Supabase at all would orphan an auth user with no profile, and every retry would
      // then fail as "email already registered".
      XCTAssertNil(
        mockSupabaseManager.capturedSignUpDateOfBirth,
        "Minor signup must be blocked before any Supabase write, or it orphans an auth user"
      )
    }
  }

  func testSignup_minorViaGuardianInvite_isAllowed() async throws {
    // The regression guarded here is the one web already shipped and had to patch in
    // 20260925000020: an over-eager minor check that rejected *valid* invited minors too.
    // InviteJoinViewModel passes viaGuardianInvite: true, which must exempt the guard.
    let fifteen = ISO8601DateFormatter.yyyyMMdd(yearsAgo: 15)

    try await sut.signup(
      email: "invited@example.com",
      password: "password123",
      fullName: "Invited Minor",
      role: .player,
      familyCode: nil,
      dateOfBirth: fifteen,
      captchaToken: "test-captcha-token",
      viaGuardianInvite: true
    )

    XCTAssertEqual(
      mockSupabaseManager.capturedSignUpDateOfBirth,
      fifteen,
      "A guardian-invited 13-17 player must still be able to create their account"
    )
  }

  func testSignup_exactlyEighteen_isAllowed() async throws {
    let eighteen = ISO8601DateFormatter.yyyyMMdd(yearsAgo: 18)

    try await sut.signup(
      email: "adult@example.com",
      password: "password123",
      fullName: "Just Eighteen",
      role: .player,
      familyCode: nil,
      dateOfBirth: eighteen,
      captchaToken: "test-captcha-token"
    )

    XCTAssertEqual(
      mockSupabaseManager.capturedSignUpDateOfBirth,
      eighteen,
      "18 is the standalone-account boundary and must not be blocked"
    )
  }

  func testSignup_parentRole_notBlockedByMinorGuard() async throws {
    // The guard is player-scoped. Parents don't supply their own DOB at signup, but if a
    // DOB ever reaches this path for a parent it must not be treated as a minor player.
    let fifteen = ISO8601DateFormatter.yyyyMMdd(yearsAgo: 15)

    try await sut.signup(
      email: "parent@example.com",
      password: "password123",
      fullName: "Parent User",
      role: .parent,
      familyCode: nil,
      dateOfBirth: fifteen,
      captchaToken: "test-captcha-token"
    )

    XCTAssertEqual(mockSupabaseManager.capturedSignUpDateOfBirth, fifteen)
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
