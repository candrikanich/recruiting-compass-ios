import XCTest
@testable import TheRecruitingCompass

@MainActor
final class InviteJoinViewModelMarketingOptInTests: XCTestCase {
  nonisolated deinit {}

  var viewModel: InviteJoinViewModel!
  var mockFamilyService: MockFamilyService!
  var mockAuthManager: MockAuthManager!

  override func setUp() {
    mockFamilyService = MockFamilyService()
    mockAuthManager = MockAuthManager()
    viewModel = InviteJoinViewModel(
      token: "invite-token-1",
      familyService: mockFamilyService,
      authManager: mockAuthManager,
      turnstileTokenProvider: MockTurnstileTokenProvider(),
      profileService: MockProfileService()
    )
  }

  override func tearDown() {
    viewModel = nil
    mockFamilyService = nil
    mockAuthManager = nil
  }

  private func yearsAgo(_ years: Int) -> Date {
    Calendar.current.date(byAdding: .year, value: -years, to: .now)!
  }

  private func loadInvite(role: String) async {
    mockFamilyService.stubbedInviteDetails = InviteDetails(
      invitationId: "inv-1",
      email: "invitee@example.com",
      role: role,
      familyName: "Test Family",
      inviterName: "Test Inviter",
      emailExists: false,
      prefill: nil,
      emailMismatch: nil
    )
    await viewModel.loadInvite()
  }

  private func setValidSignupFields(dobYearsAgo: Int) {
    viewModel.signupFirstName = "Alex"
    viewModel.signupLastName = "Rivera"
    viewModel.signupDateOfBirth = yearsAgo(dobYearsAgo)
    viewModel.signupPassword = "password123"
    viewModel.signupConfirmPassword = "password123"
    viewModel.signupAgreeToTerms = true
  }

  func test_defaultsFalse() {
    XCTAssertFalse(viewModel.signupMarketingOptIn)
  }

  func test_hidden_beforeInviteLoads() {
    XCTAssertFalse(viewModel.isMarketingOptInVisible)
  }

  func test_parentInvite_visible_evenWithMinorDOB() async {
    await loadInvite(role: "parent")
    viewModel.signupDateOfBirth = yearsAgo(15)
    XCTAssertTrue(viewModel.isMarketingOptInVisible)
  }

  func test_minorPlayerInvite_hidden() async {
    await loadInvite(role: "player")
    viewModel.signupDateOfBirth = yearsAgo(16)
    XCTAssertFalse(viewModel.isMarketingOptInVisible)
  }

  func test_adultPlayerInvite_visible() async {
    await loadInvite(role: "player")
    viewModel.signupDateOfBirth = yearsAgo(19)
    XCTAssertTrue(viewModel.isMarketingOptInVisible)
  }

  func test_resets_onDOBChange() async {
    await loadInvite(role: "player")
    viewModel.signupDateOfBirth = yearsAgo(19)
    viewModel.signupMarketingOptIn = true
    viewModel.signupDateOfBirth = yearsAgo(16)
    XCTAssertFalse(viewModel.signupMarketingOptIn)
  }

  func test_parentSignup_passesOptIn() async {
    await loadInvite(role: "parent")
    setValidSignupFields(dobYearsAgo: 30)
    viewModel.signupMarketingOptIn = true
    await viewModel.signupAndConnect()
    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertEqual(mockAuthManager.capturedSignupMarketingEmailOptIn, true)
  }

  func test_minorPlayerSignup_omitsOptIn() async {
    await loadInvite(role: "player")
    setValidSignupFields(dobYearsAgo: 16)
    await viewModel.signupAndConnect()
    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertNil(mockAuthManager.capturedSignupMarketingEmailOptIn)
  }
}
