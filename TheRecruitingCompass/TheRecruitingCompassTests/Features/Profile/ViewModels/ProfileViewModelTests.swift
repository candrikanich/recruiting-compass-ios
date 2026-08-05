import XCTest
@testable import TheRecruitingCompass

@MainActor
final class ProfileViewModelTests: XCTestCase {
  nonisolated deinit {}

  var viewModel: ProfileViewModel!
  var mockProfileService: MockProfileService!
  var mockPhotoService: MockProfilePhotoService!
  var authManager: AuthManager!
  var mockSupabaseManager: MockSupabaseManager!
  var mockBiometricService: MockBiometricService!

  override func setUp() async throws {
    // AuthManager.init schedules an unstructured Task to restore any saved Keychain
    // session. Its no-saved-session path (clearSession()) has no internal suspension
    // points, so a real Keychain leftover from another run/test could race in on our
    // test's first `await` and clobber `user` back to nil mid-test. Clear the key and
    // yield once so that Task finishes before we set our own test user.
    try? KeychainHelper.shared.delete(forKey: "savedSession")
    mockProfileService = MockProfileService()
    mockPhotoService = MockProfilePhotoService()
    mockSupabaseManager = MockSupabaseManager()
    mockBiometricService = MockBiometricService()
    authManager = AuthManager(supabaseManager: mockSupabaseManager, biometricService: mockBiometricService)
    await Task.yield()
    authManager.user = userMock()

    viewModel = ProfileViewModel(
      profileService: mockProfileService,
      photoService: mockPhotoService,
      authManager: authManager
    )
  }

  override func tearDown() {
    try? KeychainHelper.shared.delete(forKey: "savedSession")
    viewModel = nil
    mockProfileService = nil
    mockPhotoService = nil
    authManager = nil
    mockSupabaseManager = nil
    mockBiometricService = nil
  }

  // MARK: - loadInitialState

  func testLoadInitialState_populatesFromUser() {
    viewModel.loadInitialState()

    XCTAssertEqual(viewModel.fullName, "Jane Athlete")
    XCTAssertEqual(viewModel.phone, "555-1234")
    XCTAssertEqual(viewModel.dateOfBirth, "2008-05-01")
  }

  func testLoadInitialState_noUser_isNoOp() {
    authManager.user = nil
    viewModel.loadInitialState()

    XCTAssertEqual(viewModel.fullName, "")
  }

  // MARK: - loadDeletionStatus

  func testLoadDeletionStatus_noPendingRequest_setsNoRequest() async {
    mockProfileService.stubbedDeletionRequestedAt = nil

    await viewModel.loadDeletionStatus()

    XCTAssertEqual(viewModel.deletionState, .noRequest)
    XCTAssertFalse(viewModel.isLoadingDeletion)
  }

  func testLoadDeletionStatus_pendingRequest_setsPendingWith30DayWindow() async {
    let requestedAt = Date(timeIntervalSince1970: 1_700_000_000)
    mockProfileService.stubbedDeletionRequestedAt = requestedAt

    await viewModel.loadDeletionStatus()

    guard case .pending(let scheduledFor) = viewModel.deletionState else {
      return XCTFail("Expected .pending state")
    }
    let expected = Calendar.current.date(byAdding: .day, value: 30, to: requestedAt)!
    XCTAssertEqual(scheduledFor.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
  }

  func testLoadDeletionStatus_serviceThrows_fallsBackToNoRequestSilently() async {
    mockProfileService.shouldThrowOnGetDeletionStatus = true

    await viewModel.loadDeletionStatus()

    XCTAssertEqual(viewModel.deletionState, .noRequest)
  }

  // MARK: - Photo actions

  func testUploadPhoto_success_updatesCachedUserPhotoURL() async {
    mockPhotoService.stubbedUploadURL = "https://example.com/new.jpg"

    await viewModel.uploadPhoto(UIImage())

    XCTAssertEqual(mockPhotoService.uploadCallCount, 1)
    XCTAssertEqual(authManager.user?.profilePhotoUrl, "https://example.com/new.jpg")
    XCTAssertNil(viewModel.photoError)
    XCTAssertFalse(viewModel.isUploadingPhoto)
  }

  func testUploadPhoto_failure_setsPhotoError() async {
    mockPhotoService.shouldThrowOnUpload = true

    await viewModel.uploadPhoto(UIImage())

    XCTAssertNotNil(viewModel.photoError)
    XCTAssertNil(authManager.user?.profilePhotoUrl)
  }

  func testRemovePhoto_noExistingPhoto_isNoOp() async {
    await viewModel.removePhoto()
    XCTAssertEqual(mockPhotoService.deleteCallCount, 0)
  }

  func testRemovePhoto_success_clearsCachedPhotoURL() async {
    authManager.user = userMock(profilePhotoUrl: "https://example.com/existing.jpg")

    await viewModel.removePhoto()

    XCTAssertEqual(mockPhotoService.deleteCallCount, 1)
    XCTAssertNil(authManager.user?.profilePhotoUrl)
  }

  // MARK: - Personal info

  func testIsPersonalInfoValid_emptyName_isFalse() {
    viewModel.fullName = "   "
    XCTAssertFalse(viewModel.isPersonalInfoValid)
  }

  func testIsPersonalInfoValid_nonEmptyName_isTrue() {
    viewModel.fullName = "Jane Athlete"
    XCTAssertTrue(viewModel.isPersonalInfoValid)
  }

  func testSavePersonalInfo_invalidName_isNoOp() async {
    viewModel.fullName = ""
    await viewModel.savePersonalInfo()
    XCTAssertEqual(mockProfileService.updatePersonalInfoCallCount, 0)
  }

  func testSavePersonalInfo_success_updatesServiceAndCachedUser() async {
    viewModel.fullName = "  New Name  "
    viewModel.phone = "555-9999"
    viewModel.dateOfBirth = "2007-01-01"

    await viewModel.savePersonalInfo()

    XCTAssertEqual(mockProfileService.updatePersonalInfoCallCount, 1)
    XCTAssertEqual(mockProfileService.lastFullName, "New Name")
    XCTAssertEqual(mockProfileService.lastPhone, "555-9999")
    XCTAssertEqual(authManager.user?.fullName, "New Name")
    // savePersonalInfo() sets .success then sleeps 2s and clears it itself before
    // returning, so by the time `await` resumes here the message is already nil again.
    XCTAssertNil(viewModel.personalInfoMessage)
  }

  func testSavePersonalInfo_emptyPhoneAndDob_passedAsNil() async {
    viewModel.fullName = "Jane"
    viewModel.phone = "   "
    viewModel.dateOfBirth = ""

    await viewModel.savePersonalInfo()

    XCTAssertNil(mockProfileService.lastPhone)
    XCTAssertNil(mockProfileService.lastDateOfBirth)
  }

  func testSavePersonalInfo_serviceThrows_setsErrorMessage() async {
    viewModel.fullName = "Jane"
    mockProfileService.shouldThrowOnUpdatePersonalInfo = true

    await viewModel.savePersonalInfo()

    guard case .error(let message) = viewModel.personalInfoMessage else {
      return XCTFail("Expected .error message")
    }
    XCTAssertEqual(message, "Failed to save. Please try again.")
  }

  // MARK: - Email change

  func testSubmitEmailChange_success_resetsFormAndShowsBanner() async {
    viewModel.newEmail = "new@example.com"
    viewModel.emailCurrentPassword = "password123"
    viewModel.isEmailFormExpanded = true

    await viewModel.submitEmailChange()

    XCTAssertEqual(mockProfileService.changeEmailCallCount, 1)
    XCTAssertEqual(mockProfileService.lastNewEmail, "new@example.com")
    XCTAssertFalse(viewModel.isEmailFormExpanded)
    XCTAssertEqual(viewModel.newEmail, "")
    XCTAssertEqual(viewModel.emailCurrentPassword, "")
    XCTAssertTrue(viewModel.emailVerificationBannerVisible)
  }

  func testSubmitEmailChange_wrongPassword_setsSpecificErrorMessage() async {
    mockProfileService.shouldThrowOnChangeEmail = true
    mockProfileService.errorToThrow = ProfileServiceError.wrongPassword

    await viewModel.submitEmailChange()

    guard case .error(let message) = viewModel.emailMessage else {
      return XCTFail("Expected .error message")
    }
    XCTAssertEqual(message, ProfileServiceError.wrongPassword.errorDescription)
  }

  func testSubmitEmailChange_genericError_usesFallbackMessage() async {
    mockProfileService.shouldThrowOnChangeEmail = true
    mockProfileService.errorToThrow = NSError(domain: "test", code: 1)

    await viewModel.submitEmailChange()

    guard case .error(let message) = viewModel.emailMessage else {
      return XCTFail("Expected .error message")
    }
    XCTAssertEqual(message, "Failed to update email.")
  }

  // MARK: - Password change

  func testPasswordsMatch_matching_isTrue() {
    viewModel.newPassword = "password123"
    viewModel.confirmPassword = "password123"
    XCTAssertTrue(viewModel.passwordsMatch)
  }

  func testIsPasswordFormValid_shortPassword_isFalse() {
    viewModel.currentPassword = "old"
    viewModel.newPassword = "short"
    viewModel.confirmPassword = "short"
    XCTAssertFalse(viewModel.isPasswordFormValid)
  }

  func testIsPasswordFormValid_validState_isTrue() {
    viewModel.currentPassword = "old"
    viewModel.newPassword = "newpassword1"
    viewModel.confirmPassword = "newpassword1"
    XCTAssertTrue(viewModel.isPasswordFormValid)
  }

  func testSavePassword_invalidForm_isNoOp() async {
    viewModel.currentPassword = ""
    await viewModel.savePassword()
    XCTAssertEqual(mockProfileService.changePasswordCallCount, 0)
  }

  func testSavePassword_success_clearsFieldsAndShowsSuccess() async {
    viewModel.currentPassword = "old"
    viewModel.newPassword = "newpassword1"
    viewModel.confirmPassword = "newpassword1"

    await viewModel.savePassword()

    XCTAssertEqual(mockProfileService.changePasswordCallCount, 1)
    XCTAssertEqual(viewModel.currentPassword, "")
    XCTAssertEqual(viewModel.newPassword, "")
    // Same as savePersonalInfo(): the .success message is set then cleared internally
    // after a 2s sleep, so it's already nil again by the time await resumes here.
    XCTAssertNil(viewModel.passwordMessage)
  }

  func testSavePassword_serviceThrows_setsErrorMessage() async {
    viewModel.currentPassword = "old"
    viewModel.newPassword = "newpassword1"
    viewModel.confirmPassword = "newpassword1"
    mockProfileService.shouldThrowOnChangePassword = true

    await viewModel.savePassword()

    guard case .error = viewModel.passwordMessage else {
      return XCTFail("Expected .error message")
    }
  }

  // MARK: - Deletion flow

  func testBeginDeletionRequest_setsConfirmStep() {
    viewModel.beginDeletionRequest()
    XCTAssertEqual(viewModel.deletionState, .confirmStep)
  }

  func testCancelDeletionConfirm_returnsToNoRequest() {
    viewModel.beginDeletionRequest()
    viewModel.cancelDeletionConfirm()
    XCTAssertEqual(viewModel.deletionState, .noRequest)
  }

  func testConfirmDeletion_success_setsPendingState() async {
    await viewModel.confirmDeletion()

    XCTAssertEqual(mockProfileService.requestDeletionCallCount, 1)
    guard case .pending = viewModel.deletionState else {
      return XCTFail("Expected .pending state")
    }
    XCTAssertNil(viewModel.deletionError)
  }

  func testConfirmDeletion_failure_setsErrorAndRevertsState() async {
    mockProfileService.shouldThrowOnRequestDeletion = true

    await viewModel.confirmDeletion()

    XCTAssertNotNil(viewModel.deletionError)
    XCTAssertEqual(viewModel.deletionState, .noRequest)
  }

  func testCancelDeletionRequest_success_returnsToNoRequest() async {
    await viewModel.confirmDeletion()
    await viewModel.cancelDeletionRequest()

    XCTAssertEqual(mockProfileService.cancelDeletionCallCount, 1)
    XCTAssertEqual(viewModel.deletionState, .noRequest)
  }

  func testCancelDeletionRequest_failure_setsErrorMessage() async {
    mockProfileService.shouldThrowOnCancelDeletion = true

    await viewModel.cancelDeletionRequest()

    XCTAssertNotNil(viewModel.deletionError)
  }

  // MARK: - Helpers

  private func userMock(profilePhotoUrl: String? = nil) -> User {
    User(
      id: "user-1",
      email: "jane@example.com",
      emailConfirmedAt: "2026-01-01T00:00:00Z",
      phone: "555-1234",
      fullName: "Jane Athlete",
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      role: .player,
      dateOfBirth: "2008-05-01",
      profilePhotoUrl: profilePhotoUrl
    )
  }
}

extension ProfileViewModel.DeletionState: Equatable {
  public static func == (lhs: ProfileViewModel.DeletionState, rhs: ProfileViewModel.DeletionState) -> Bool {
    switch (lhs, rhs) {
    case (.noRequest, .noRequest), (.confirmStep, .confirmStep):
      return true
    case (.pending(let l), .pending(let r)):
      return l == r
    default:
      return false
    }
  }
}
