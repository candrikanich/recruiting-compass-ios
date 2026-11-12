import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AnalyticsEventsTests: XCTestCase {
  nonisolated deinit {}
  private var transport: RecordingTransport!
  private var originalTransport: (any AnalyticsTransport)!

  override func setUp() {
    super.setUp()
    originalTransport = Analytics.transport
    transport = RecordingTransport()
    Analytics.transport = transport
  }

  override func tearDown() {
    Analytics.transport = originalTransport
    transport = nil
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

  func testParentWizard_startedFiresOnceEvenIfShownTwice() {
    let viewModel = ParentOnboardingWizardViewModel(
      familyService: MockFamilyService(), authManager: MockAuthManager(), onboardingService: MockOnboardingService()
    )

    viewModel.trackOnboardingStarted()
    viewModel.trackOnboardingStarted()

    let fired = transport.events(named: "onboarding_v2_started")
    XCTAssertEqual(fired.count, 1)
    XCTAssertEqual(fired.first?.properties["role"] as? String, "parent")
  }

  func testOnboardingAnalytics_schoolAddedCarriesNoSchoolName() {
    OnboardingAnalytics.schoolAdded()

    XCTAssertEqual(transport.events(named: "onboarding_v2_school_added").first?.properties.keys.sorted(), ["platform"])
  }
}
