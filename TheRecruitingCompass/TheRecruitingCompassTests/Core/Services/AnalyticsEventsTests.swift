import PostHog
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AnalyticsEventsTests: XCTestCase {
  nonisolated deinit {}
  private var harness: AnalyticsHarness!
  private var transport: RecordingTransport { harness.transport }

  override func setUp() {
    super.setUp()
    harness = AnalyticsHarness()
  }

  override func tearDown() {
    harness.restore()
    harness = nil
    super.tearDown()
  }

  private func makeAuthManager() -> (AuthManager, MockSupabaseManager) {
    let supabase = MockSupabaseManager()
    supabase.signUpResult = .success((user: userMock(), session: nil))
    return (AuthManager(supabaseManager: supabase, biometricService: MockBiometricService()), supabase)
  }

  private func userMock() -> User {
    User(
      id: "user-1", email: "pat@example.com", emailConfirmedAt: nil,
      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z", role: .parent
    )
  }

  // MARK: - identify carries an opaque ID only

  func testIdentify_sendsNoEmailOrDirectIdentifier() {
    Analytics.identify(userId: "user-1", role: "parent")

    let sent = transport.identifies.first
    XCTAssertEqual(sent?.userId, "user-1")
    let keys = Set(sent?.properties.keys.map { $0 } ?? [])
    XCTAssertEqual(keys, ["platform", "role"], "identify may carry only platform and role")
  }

  // MARK: - signup_completed

  func testSignup_firesSignupCompletedOnceWithRoleOnly() async throws {
    let (auth, _) = makeAuthManager()

    try await auth.signup(
      email: "pat@example.com", password: "password123", fullName: "Pat Doe",
      role: .parent, familyCode: nil, captchaToken: "t"
    )

    let fired = transport.events(named: "signup_completed")
    XCTAssertEqual(fired.count, 1)
    XCTAssertEqual(fired.first?.properties["role"] as? String, "parent")
    XCTAssertEqual(Set(fired.first?.properties.keys.map { $0 } ?? []), ["role", "platform"])
  }

  func testSignup_failure_doesNotFireSignupCompleted() async {
    let (auth, supabase) = makeAuthManager()
    supabase.signUpResult = .failure(AuthError.serverError("nope"))

    try? await auth.signup(
      email: "pat@example.com", password: "password123", fullName: "Pat Doe",
      role: .parent, familyCode: nil, captchaToken: "t"
    )

    XCTAssertTrue(transport.events(named: "signup_completed").isEmpty)
  }

  // MARK: - parent onboarding

  func testParentWizard_startedFiresOnceEvenAcrossViewModelInstances() {
    let auth = MockAuthManager()
    auth.setMockUser(userMock())
    func makeViewModel() -> ParentOnboardingWizardViewModel {
      ParentOnboardingWizardViewModel(
        familyService: MockFamilyService(), authManager: auth, onboardingService: MockOnboardingService()
      )
    }

    makeViewModel().trackOnboardingStarted()
    makeViewModel().trackOnboardingStarted()

    let fired = transport.events(named: "onboarding_v2_started")
    XCTAssertEqual(fired.count, 1)
    XCTAssertEqual(fired.first?.properties["role"] as? String, "parent")
  }

  func testOnboardingStarted_playerFiresOncePerUserEvenIfTaskRerun() {
    let player = User(
      id: "p-1", email: "p@example.com", emailConfirmedAt: nil,
      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z", role: .player
    )

    OnboardingAnalytics.onboardingStarted(user: player)
    OnboardingAnalytics.onboardingStarted(user: player)

    XCTAssertEqual(transport.events(named: "onboarding_v2_started").count, 1)
    XCTAssertEqual(transport.events(named: "onboarding_v2_started").first?.properties["role"] as? String, "player")
  }

  func testOnboardingStarted_unknownRoleSendsNothingThenFiresOnceRoleKnown() {
    let noRole = User(
      id: "p-2", email: "p@example.com", emailConfirmedAt: nil,
      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z", role: nil
    )
    OnboardingAnalytics.onboardingStarted(user: noRole)
    OnboardingAnalytics.onboardingStarted(user: nil)
    XCTAssertTrue(transport.events(named: "onboarding_v2_started").isEmpty, "never guess a role")

    OnboardingAnalytics.onboardingStarted(role: .player, userId: "p-2")

    XCTAssertEqual(transport.events(named: "onboarding_v2_started").count, 1)
  }

  func testIdentify_unsetsStoredEmailOnExistingProfiles() {
    Analytics.identify(userId: "user-1")

    XCTAssertEqual(transport.unsets, [["email"]])
  }

  func testSignupWithSession_identifiesBeforeSignupCompleted() async throws {
    let (auth, supabase) = makeAuthManager()
    let session = Session(
      accessToken: "a", tokenType: "bearer", expiresIn: 3600, expiresAt: 4_000_000_000, refreshToken: "r", user: userMock()
    )
    supabase.signUpResult = .success((user: userMock(), session: session))

    try await auth.signup(
      email: "pat@example.com", password: "password123", fullName: "Pat Doe",
      role: .parent, familyCode: nil, captchaToken: "t"
    )

    XCTAssertEqual(transport.identifies.map(\.userId), ["user-1"])
    XCTAssertEqual(transport.events(named: "signup_completed").count, 1)
    XCTAssertEqual(transport.order.first, "identify", "identify must precede signup_completed")
  }

  func testOnboardingAnalytics_schoolAddedCarriesNoSchoolName() {
    OnboardingAnalytics.schoolAdded()

    XCTAssertEqual(transport.events(named: "onboarding_v2_school_added").first?.properties.keys.sorted(), ["platform"])
  }

  // MARK: - hostile cases (from verifier)

  func testSignup_accountCreatedButSignInFailed_stillCountsNewAccount() async {
    let (auth, supabase) = makeAuthManager()
    supabase.signUpResult = .failure(AuthError.accountCreatedButSignInFailed("sign-in failed"))

    try? await auth.signup(
      email: "a@example.com", password: "password123", fullName: "A B",
      role: .parent, familyCode: nil, captchaToken: "t"
    )

    XCTAssertEqual(transport.events(named: "signup_completed").count, 1)
    XCTAssertEqual(transport.events(named: "signup_completed").first?.properties["role"] as? String, "parent")
  }

  func testAdultPlayerSignup_reportsPlayerRole() async throws {
    let (auth, _) = makeAuthManager()

    try await auth.signup(
      email: "e@example.com", password: "password123", fullName: "E F",
      role: .player, familyCode: nil, captchaToken: "t"
    )

    XCTAssertEqual(transport.events(named: "signup_completed").first?.properties["role"] as? String, "player")
  }

  func testMinorSignupFailure_firesNoSignupCompleted() async {
    let guardian = MockGuardianService()
    guardian.shouldThrowSignupMinorError = true
    guardian.mockErrorToThrow = GuardianServiceError.server(400, message: "nope")
    let sut = SignupViewModel(
      authManager: MockAuthManager(), guardianService: guardian, turnstileTokenProvider: MockTurnstileTokenProvider()
    )
    sut.selectRole(.player)
    sut.firstName = "John"; sut.lastName = "Doe"; sut.email = "j@example.com"
    sut.password = "StrongPass123"; sut.confirmPassword = "StrongPass123"; sut.termsAccepted = true
    sut.dateOfBirth = Calendar.current.date(byAdding: .year, value: -15, to: .now)!
    sut.guardianEmail = "g@example.com"
    sut.graduationYear = 2028; sut.primarySport = "Soccer"

    await sut.signup()

    XCTAssertEqual(sut.errorMessage, "nope", "must reach the guardian call")
    XCTAssertTrue(transport.events(named: "signup_completed").isEmpty)
  }

  func testPlayerOnboardingComplete_carriesRoleAndItemCount() {
    OnboardingAnalytics.onboardingComplete(role: .player, completedItems: 2)

    let fired = transport.events(named: "onboarding_v2_complete").first
    XCTAssertEqual(fired?.properties["role"] as? String, "player")
    XCTAssertEqual(fired?.properties["completedItems"] as? Int, 2)
  }

  func testChecklistItemCompleted_carriesRoleOfSignedInUser() {
    let manager = NuxProgressManager(service: MockNuxProgressService(), roleProvider: { .parent })

    manager.completeItem(.sport)

    let fired = transport.events(named: "checklist_item_completed")
    XCTAssertEqual(fired.count, 1)
    XCTAssertEqual(fired.first?.properties["role"] as? String, "parent")
  }

  // MARK: - stale person properties (email on upgraded installs)

  func testConfig_doesNotPreloadFeatureFlags() {
    XCTAssertFalse(Analytics.makeConfig(key: "phc_test").preloadFeatureFlags)
  }

  func testSetup_clearsPersistedPersonProperties() {
    Analytics.setup()

    XCTAssertEqual(transport.clearPersistedCount, 1)
  }
}
