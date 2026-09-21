import XCTest
@testable import TheRecruitingCompass

@MainActor
final class InviteJoinViewModelTests: XCTestCase {
  nonisolated deinit {}

  var viewModel: InviteJoinViewModel!
  var mockFamilyService: MockFamilyService!
  var mockAuthManager: MockAuthManager!
  var mockTurnstileProvider: MockTurnstileTokenProvider!

  override func setUp() {
    mockFamilyService = MockFamilyService()
    mockAuthManager = MockAuthManager()
    mockTurnstileProvider = MockTurnstileTokenProvider()
    viewModel = InviteJoinViewModel(
      token: "invite-token-1",
      familyService: mockFamilyService,
      authManager: mockAuthManager,
      turnstileTokenProvider: mockTurnstileProvider
    )
  }

  override func tearDown() {
    viewModel = nil
    mockFamilyService = nil
    mockAuthManager = nil
    mockTurnstileProvider = nil
  }

  // MARK: - loadInvite

  func testLoadInvite_success_populatesStateAndLoginEmail() async {
    mockFamilyService.stubbedInviteDetails = makeInviteDetails(email: "invitee@example.com")

    await viewModel.loadInvite()

    XCTAssertEqual(viewModel.inviteDetails?.email, "invitee@example.com")
    XCTAssertEqual(viewModel.loginEmail, "invitee@example.com")
  }

  func testLoadInvite_withPrefill_populatesSignupNames() async {
    mockFamilyService.stubbedInviteDetails = makeInviteDetails(
      prefill: InvitePrefill(firstName: "Alex", lastName: "Rivera")
    )

    await viewModel.loadInvite()

    XCTAssertEqual(viewModel.signupFirstName, "Alex")
    XCTAssertEqual(viewModel.signupLastName, "Rivera")
  }

  func testLoadInvite_inviteError_setsErrorState() async {
    mockFamilyService.shouldSucceed = false
    mockFamilyService.mockError = InviteError.expired

    await viewModel.loadInvite()

    guard case .error(let err) = viewModel.state else {
      return XCTFail("Expected .error state")
    }
    XCTAssertEqual(err, .expired)
  }

  func testLoadInvite_genericError_wrapsAsServerError() async {
    mockFamilyService.shouldSucceed = false
    mockFamilyService.mockError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])

    await viewModel.loadInvite()

    guard case .error(.serverError(let message)) = viewModel.state else {
      return XCTFail("Expected .error(.serverError)")
    }
    XCTAssertEqual(message, "boom")
  }

  // MARK: - accept()

  func testAccept_alreadyAuthenticated_skipsLoginAndAcceptsInvite() async {
    mockAuthManager.isAuthenticated = true

    await viewModel.accept()

    XCTAssertEqual(mockAuthManager.loginCallCount, 0)
    XCTAssertEqual(mockFamilyService.acceptInviteCallCount, 1)
    XCTAssertTrue(viewModel.navigateToDashboard)
    XCTAssertEqual(viewModel.successMessage, "You're connected!")
  }

  func testAccept_notAuthenticated_logsInThenAccepts() async {
    mockAuthManager.isAuthenticated = false
    viewModel.loginEmail = "user@example.com"
    viewModel.loginPassword = "password123"

    await viewModel.accept()

    XCTAssertEqual(mockAuthManager.loginCallCount, 1)
    XCTAssertEqual(mockFamilyService.acceptInviteCallCount, 1)
    XCTAssertTrue(viewModel.navigateToDashboard)
  }

  func testAccept_emailMismatch_showsMismatchMessage() async {
    mockFamilyService.stubbedInviteDetails = makeInviteDetails(emailMismatch: true)
    await viewModel.loadInvite()
    mockAuthManager.isAuthenticated = true

    await viewModel.accept()

    XCTAssertEqual(viewModel.successMessage, "You're connected! (You used a different email than the invite.)")
  }

  func testAccept_loginFails_setsErrorMessage_doesNotAcceptInvite() async {
    mockAuthManager.isAuthenticated = false
    mockAuthManager.shouldThrowLoginError = true

    await viewModel.accept()

    XCTAssertEqual(mockFamilyService.acceptInviteCallCount, 0)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.navigateToDashboard)
  }

  // Regression: acceptInvite must run BEFORE authManager publishes isAuthenticated, so the
  // onboarding gate's fetch (triggered the instant isAuthenticated flips true) never races the
  // server's hydrateAthleteFromPendingDetails() write.
  func testAccept_notAuthenticated_acceptsInviteBeforeAuthPublishes() async {
    mockAuthManager.isAuthenticated = false
    viewModel.loginEmail = "user@example.com"
    viewModel.loginPassword = "password123"
    var isAuthenticatedDuringAccept: Bool?
    mockFamilyService.onAcceptInvite = { [weak mockAuthManager] in
      isAuthenticatedDuringAccept = mockAuthManager?.isAuthenticated
    }

    await viewModel.accept()

    XCTAssertEqual(mockFamilyService.acceptInviteCallCount, 1)
    XCTAssertEqual(isAuthenticatedDuringAccept, false, "acceptInvite must run before isAuthenticated publishes")
    XCTAssertTrue(mockAuthManager.isAuthenticated, "isAuthenticated should still publish true after a successful accept")
    XCTAssertTrue(viewModel.navigateToDashboard)
  }

  func testAccept_notAuthenticated_acceptInviteFails_setsErrorMessage_doesNotPublishSuccess() async {
    mockAuthManager.isAuthenticated = false
    mockFamilyService.shouldSucceed = false
    mockFamilyService.mockError = InviteError.alreadyAccepted

    await viewModel.accept()

    XCTAssertEqual(viewModel.errorMessage, InviteError.alreadyAccepted.errorDescription)
    XCTAssertFalse(viewModel.navigateToDashboard)
  }

  func testAccept_acceptInviteFails_setsErrorMessage() async {
    mockAuthManager.isAuthenticated = true
    mockFamilyService.shouldSucceed = false
    mockFamilyService.mockError = InviteError.alreadyAccepted

    await viewModel.accept()

    XCTAssertEqual(viewModel.errorMessage, InviteError.alreadyAccepted.errorDescription)
    XCTAssertFalse(viewModel.navigateToDashboard)
  }

  // MARK: - signupAndConnect() validation

  func testSignupAndConnect_noInviteDetails_isNoOp() async {
    await viewModel.signupAndConnect()
    XCTAssertEqual(mockAuthManager.signupCallCount, 0)
  }

  func testSignupAndConnect_emptyName_setsError() async {
    mockFamilyService.stubbedInviteDetails = makeInviteDetails()
    await viewModel.loadInvite()
    viewModel.signupFirstName = ""
    viewModel.signupLastName = "Rivera"

    await viewModel.signupAndConnect()

    XCTAssertEqual(viewModel.signupError, "Please enter your first and last name")
    XCTAssertEqual(mockAuthManager.signupCallCount, 0)
  }

  func testSignupAndConnect_playerUnderage_setsError() async {
    mockFamilyService.stubbedInviteDetails = makeInviteDetails(role: "player")
    await viewModel.loadInvite()
    viewModel.signupFirstName = "Alex"
    viewModel.signupLastName = "Rivera"
    viewModel.signupDateOfBirth = Calendar.current.date(byAdding: .year, value: -10, to: .now) ?? .now

    await viewModel.signupAndConnect()

    XCTAssertEqual(viewModel.signupError, "Players must be 13 or older")
    XCTAssertEqual(mockAuthManager.signupCallCount, 0)
  }

  func testSignupAndConnect_passwordMismatch_setsError() async {
    mockFamilyService.stubbedInviteDetails = makeInviteDetails()
    await viewModel.loadInvite()
    setValidSignupFields()
    viewModel.signupPassword = "password123"
    viewModel.signupConfirmPassword = "different123"

    await viewModel.signupAndConnect()

    XCTAssertEqual(viewModel.signupError, "Passwords don't match")
  }

  func testSignupAndConnect_shortPassword_setsError() async {
    mockFamilyService.stubbedInviteDetails = makeInviteDetails()
    await viewModel.loadInvite()
    setValidSignupFields()
    viewModel.signupPassword = "short"
    viewModel.signupConfirmPassword = "short"

    await viewModel.signupAndConnect()

    XCTAssertEqual(viewModel.signupError, "Password must be at least 8 characters")
  }

  func testSignupAndConnect_doesNotAgreeToTerms_setsError() async {
    mockFamilyService.stubbedInviteDetails = makeInviteDetails()
    await viewModel.loadInvite()
    setValidSignupFields()
    viewModel.signupAgreeToTerms = false

    await viewModel.signupAndConnect()

    XCTAssertEqual(viewModel.signupError, "Please agree to the Terms and Privacy Policy")
  }

  func testSignupAndConnect_success_signsUpAndAcceptsInvite() async {
    mockFamilyService.stubbedInviteDetails = makeInviteDetails(email: "invitee@example.com", role: "parent")
    await viewModel.loadInvite()
    setValidSignupFields()

    await viewModel.signupAndConnect()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertEqual(mockFamilyService.acceptInviteCallCount, 1)
    XCTAssertTrue(viewModel.navigateToDashboard)
    XCTAssertNil(viewModel.signupError)
  }

  // Athlete PII (sport/gradYear/position) is never present in InviteDetails.prefill — the
  // unauthenticated invite-preview lookup deliberately withholds it (see loadInvite's
  // emailExists comment). It's hydrated server-side by the accept endpoint instead
  // (hydrateAthleteFromPendingDetails), which is why signupAndConnect no longer reads
  // invite.prefill at all: accepting the invite (not passing prefill data through signup)
  // is what makes that hydration happen before the onboarding gate can observe an empty sport.
  func testSignupAndConnect_playerRole_doesNotPassPrefillIntoSignup() async {
    mockFamilyService.stubbedInviteDetails = makeInviteDetails(role: "player")
    await viewModel.loadInvite()
    setValidSignupFields()
    viewModel.signupDateOfBirth = Calendar.current.date(byAdding: .year, value: -16, to: .now) ?? .now

    await viewModel.signupAndConnect()

    XCTAssertNil(mockAuthManager.capturedSignupPrimarySport)
    XCTAssertNil(mockAuthManager.capturedSignupGraduationYear)
    XCTAssertEqual(mockFamilyService.acceptInviteCallCount, 1)
    XCTAssertEqual(viewModel.successMessage, "You're connected!")
  }

  func testSignupAndConnect_acceptInviteFails_setsSignupErrorAndDoesNotNavigate() async {
    mockFamilyService.stubbedInviteDetails = makeInviteDetails(role: "player")
    await viewModel.loadInvite()
    setValidSignupFields()
    viewModel.signupDateOfBirth = Calendar.current.date(byAdding: .year, value: -16, to: .now) ?? .now
    mockFamilyService.shouldSucceed = false

    await viewModel.signupAndConnect()

    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertNotNil(viewModel.signupError)
    XCTAssertFalse(viewModel.navigateToDashboard)
  }

  func testSignupAndConnect_signupFails_setsSignupError() async {
    mockFamilyService.stubbedInviteDetails = makeInviteDetails()
    await viewModel.loadInvite()
    setValidSignupFields()
    mockAuthManager.shouldThrowSignupError = true

    await viewModel.signupAndConnect()

    XCTAssertNotNil(viewModel.signupError)
    XCTAssertEqual(mockFamilyService.acceptInviteCallCount, 0)
    XCTAssertFalse(viewModel.navigateToDashboard)
  }

  // MARK: - decline()

  func testDecline_success_setsDeclinedState() async {
    await viewModel.decline()

    XCTAssertEqual(mockFamilyService.declineInviteCallCount, 1)
    XCTAssertEqual(viewModel.state, .declined)
  }

  func testDecline_failure_setsErrorMessage() async {
    mockFamilyService.shouldSucceed = false

    await viewModel.decline()

    XCTAssertEqual(viewModel.errorMessage, "Failed to decline invite. Please try again.")
    XCTAssertNotEqual(viewModel.state, .declined)
  }

  // MARK: - Helpers

  private func setValidSignupFields() {
    viewModel.signupFirstName = "Alex"
    viewModel.signupLastName = "Rivera"
    viewModel.signupDateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    viewModel.signupPassword = "password123"
    viewModel.signupConfirmPassword = "password123"
    viewModel.signupAgreeToTerms = true
  }

  private func makeInviteDetails(
    email: String = "invitee@example.com",
    role: String = "parent",
    emailMismatch: Bool? = nil,
    prefill: InvitePrefill? = nil,
    emailExists: Bool = false
  ) -> InviteDetails {
    InviteDetails(
      invitationId: "inv-1",
      email: email,
      role: role,
      familyName: "Test Family",
      inviterName: "Test Inviter",
      emailExists: emailExists,
      prefill: prefill,
      emailMismatch: emailMismatch
    )
  }
}

// #151 review: the server always sends emailExists=false (no account-existence
// disclosure pre-acceptance), so an existing invitee must have a manual way to
// reach the login form instead of being stuck on signup.
extension InviteJoinViewModelTests {
  func testShowsLoginSection_defaultsToServerHint_whenNoOverride() {
    XCTAssertFalse(viewModel.showsLoginSection(for: makeInviteDetails(emailExists: false)))
    XCTAssertTrue(viewModel.showsLoginSection(for: makeInviteDetails(emailExists: true)))
  }

  func testShowsLoginSection_manualOverrideWinsOverServerHint() {
    viewModel.authModeOverride = true
    XCTAssertTrue(viewModel.showsLoginSection(for: makeInviteDetails(emailExists: false)))

    viewModel.authModeOverride = false
    XCTAssertFalse(viewModel.showsLoginSection(for: makeInviteDetails(emailExists: true)))
  }
}
