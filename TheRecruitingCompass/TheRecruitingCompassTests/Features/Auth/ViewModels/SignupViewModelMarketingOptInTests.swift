import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SignupViewModelMarketingOptInTests: XCTestCase {
  nonisolated deinit {}
  var sut: SignupViewModel!
  var mockAuthManager: MockAuthManager!

  override func setUp() {
    super.setUp()
    mockAuthManager = MockAuthManager()
    sut = SignupViewModel(
      authManager: mockAuthManager,
      familyService: MockFamilyService(),
      guardianService: MockGuardianService(),
      turnstileTokenProvider: MockTurnstileTokenProvider()
    )
  }

  override func tearDown() {
    sut = nil
    mockAuthManager = nil
    super.tearDown()
  }

  private func yearsAgo(_ years: Int) -> Date {
    Calendar.current.date(byAdding: .year, value: -years, to: .now)!
  }

  private func fillValidForm(role: UserRole, dobYearsAgo: Int = 20) {
    sut.selectRole(role)
    sut.firstName = "John"
    sut.lastName = "Doe"
    sut.email = "john@example.com"
    sut.password = "StrongPass123"
    sut.confirmPassword = "StrongPass123"
    sut.termsAccepted = true
    if role == .player {
      sut.graduationYear = 2028
      sut.primarySport = "Soccer"
      sut.dateOfBirth = yearsAgo(dobYearsAgo)
    }
  }

  func test_marketingOptIn_defaultsFalse() {
    XCTAssertFalse(sut.marketingOptIn)
  }

  func test_visible_forParent() {
    sut.selectRole(.parent)
    XCTAssertTrue(sut.isMarketingOptInVisible)
  }

  func test_hidden_for17YearOldPlayer() {
    sut.selectRole(.player)
    sut.dateOfBirth = yearsAgo(17)
    XCTAssertFalse(sut.isMarketingOptInVisible)
  }

  func test_visible_for18PlusPlayer() {
    sut.selectRole(.player)
    sut.dateOfBirth = yearsAgo(18)
    XCTAssertTrue(sut.isMarketingOptInVisible)
  }

  func test_hidden_beforeRoleSelected() {
    XCTAssertFalse(sut.isMarketingOptInVisible)
  }

  func test_resets_onDOBChange() {
    sut.selectRole(.player)
    sut.dateOfBirth = yearsAgo(25)
    sut.marketingOptIn = true
    sut.dateOfBirth = yearsAgo(16)
    XCTAssertFalse(sut.marketingOptIn)
  }

  func test_resets_onRoleChange() {
    sut.selectRole(.parent)
    sut.marketingOptIn = true
    sut.selectRole(.player)
    XCTAssertFalse(sut.marketingOptIn)
  }

  func test_resets_onBackToRoleSelection() {
    sut.selectRole(.parent)
    sut.marketingOptIn = true
    sut.backToRoleSelection()
    XCTAssertFalse(sut.marketingOptIn)
  }

  func test_signup_parentOptedIn_passesTrue() async {
    fillValidForm(role: .parent)
    sut.marketingOptIn = true
    await sut.signup()
    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertEqual(mockAuthManager.capturedSignupMarketingEmailOptIn, true)
  }

  func test_signup_parentNotOptedIn_passesFalse() async {
    fillValidForm(role: .parent)
    await sut.signup()
    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertEqual(mockAuthManager.capturedSignupMarketingEmailOptIn, false)
  }

  func test_signup_adultPlayerOptedIn_passesTrue() async {
    fillValidForm(role: .player, dobYearsAgo: 20)
    sut.marketingOptIn = true
    await sut.signup()
    XCTAssertEqual(mockAuthManager.signupCallCount, 1)
    XCTAssertEqual(mockAuthManager.capturedSignupMarketingEmailOptIn, true)
  }
}
