import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AuthManagerTests: XCTestCase {
  nonisolated deinit {}
  var sut: AuthManager!
  var mockSupabaseManager: MockSupabaseManager!
  var mockAccountProvisioning: MockAccountProvisioning!

  override func setUp() {
    super.setUp()
    // AuthManager.init() always fires an unstructured Task { await restoreSession() }
    // against the REAL device Keychain (not mocked) — a session a previous test's
    // login()/signup() actually saved can leak into this test's fresh AuthManager and
    // race its own explicit login()/signup() call, double-counting flush calls or
    // otherwise making assertions non-deterministic. Clearing it first guarantees
    // restoreSession() reliably takes the "no saved session" branch in every test here.
    try? KeychainHelper.shared.delete(forKey: "savedSession")
    mockSupabaseManager = MockSupabaseManager()
    mockAccountProvisioning = MockAccountProvisioning()
    sut = AuthManager(supabaseManager: mockSupabaseManager, accountProvisioning: mockAccountProvisioning)
  }

  override func tearDown() {
    try? KeychainHelper.shared.delete(forKey: "savedSession")
    sut = nil
    mockSupabaseManager = nil
    mockAccountProvisioning = nil
    super.tearDown()
  }

  func testLoginForwardsCaptchaToken() async throws {
    let user = User(
      id: "test-user-id", email: "user@example.com", emailConfirmedAt: nil,
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
      id: "test-user-id", email: "user@example.com", emailConfirmedAt: nil,
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

  func testLoginFlushesPendingOnboardingStep1() async throws {
    let user = User(
      id: "test-user-id", email: "user@example.com", emailConfirmedAt: "2024-01-01T00:00:00Z",
      fullName: nil, createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z",
      role: nil, dateOfBirth: nil
    )
    let session = Session(
      accessToken: "token", tokenType: "bearer", expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + 3600, refreshToken: "refresh", user: user
    )
    mockSupabaseManager.signInResult = .success((user: user, session: session))

    try await sut.login(email: "user@example.com", password: "password123", captchaToken: "test-captcha-token")

    XCTAssertEqual(mockAccountProvisioning.flushCallCount, 1)
  }

  // Regression: OnboardingContainerView decides its starting step from canonical
  // preferences the instant it sees isAuthenticated flip true. If flush ran after that,
  // the container could read empty preferences and show the redundant Step 1 to a player
  // whose signup-time sport/grad-year data hadn't landed yet.
  func testLoginFlushesBeforePublishingIsAuthenticated() async throws {
    let user = User(
      id: "test-user-id", email: "user@example.com", emailConfirmedAt: "2024-01-01T00:00:00Z",
      fullName: nil, createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z",
      role: nil, dateOfBirth: nil
    )
    let session = Session(
      accessToken: "token", tokenType: "bearer", expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + 3600, refreshToken: "refresh", user: user
    )
    mockSupabaseManager.signInResult = .success((user: user, session: session))
    var isAuthenticatedAtFlushTime: Bool?
    mockAccountProvisioning.onFlush = { [weak sut] in isAuthenticatedAtFlushTime = sut?.isAuthenticated }

    try await sut.login(email: "user@example.com", password: "password123", captchaToken: "test-captcha-token")

    XCTAssertEqual(isAuthenticatedAtFlushTime, false)
    XCTAssertTrue(sut.isAuthenticated)
  }

  func testSignupWithImmediateSessionFlushesPendingOnboardingStep1() async throws {
    let user = User(
      id: "test-user-id", email: "user@example.com", emailConfirmedAt: "2024-01-01T00:00:00Z",
      fullName: "Jane Doe", createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z",
      role: .player, dateOfBirth: nil
    )
    let session = Session(
      accessToken: "token", tokenType: "bearer", expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + 3600, refreshToken: "refresh", user: user
    )
    mockSupabaseManager.signUpResult = .success((user: user, session: session))
    var isAuthenticatedAtFlushTime: Bool?
    mockAccountProvisioning.onFlush = { [weak sut] in isAuthenticatedAtFlushTime = sut?.isAuthenticated }

    try await sut.signup(
      email: "user@example.com", password: "password123", fullName: "Jane Doe",
      role: .player, familyCode: nil, dateOfBirth: "2005-01-01", captchaToken: "test-captcha-token"
    )

    XCTAssertEqual(mockAccountProvisioning.flushCallCount, 1)
    XCTAssertEqual(isAuthenticatedAtFlushTime, false, "flush must run before isAuthenticated is published")
    XCTAssertTrue(sut.isAuthenticated)
  }

  // A signup that requires email confirmation returns no session — there's no
  // authenticated user yet to flush pending metadata for.
  func testSignupWithoutSessionDoesNotFlush() async throws {
    let user = User(
      id: "test-user-id", email: "user@example.com", emailConfirmedAt: nil,
      fullName: "Jane Doe", createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z",
      role: .player, dateOfBirth: nil
    )
    mockSupabaseManager.signUpResult = .success((user: user, session: nil))

    try await sut.signup(
      email: "user@example.com", password: "password123", fullName: "Jane Doe",
      role: .player, familyCode: nil, dateOfBirth: "2005-01-01", captchaToken: "test-captcha-token"
    )

    XCTAssertEqual(mockAccountProvisioning.flushCallCount, 0)
  }

  func testSignupThreadsOnboardingStep1FieldsToSupabaseManager() async throws {
    let user = User(
      id: "test-user-id", email: "user@example.com", emailConfirmedAt: nil,
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
      dateOfBirth: "2010-01-01",
      graduationYear: 2028,
      primarySport: "Soccer",
      gender: "female",
      zipCode: "94105",
      captchaToken: "test-captcha-token"
    )

    XCTAssertEqual(mockSupabaseManager.capturedSignUpGraduationYear, 2028)
    XCTAssertEqual(mockSupabaseManager.capturedSignUpPrimarySport, "Soccer")
    XCTAssertEqual(mockSupabaseManager.capturedSignUpGender, "female")
    XCTAssertEqual(mockSupabaseManager.capturedSignUpZipCode, "94105")
  }
}
