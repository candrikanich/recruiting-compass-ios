import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AddInteractionViewModelTests: XCTestCase {
  nonisolated deinit {}
  var viewModel: AddInteractionViewModel!
  var mockService: MockInteractionsService!

  override func setUp() async throws {
    mockService = MockInteractionsService()
    viewModel = AddInteractionViewModel(
      interactionsService: mockService,
      familyUnitId: "family1",
      userId: "user1"
    )
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
  }

  // MARK: - Initialization Tests

  func testInit_SetsDefaultFormState() {
    XCTAssertEqual(viewModel.formState.direction, .outbound)
    XCTAssertTrue(viewModel.formState.schoolId.isEmpty)
    XCTAssertNil(viewModel.formState.coachId)
    XCTAssertNil(viewModel.formState.type)
    XCTAssertEqual(viewModel.formState.interestLevel, .notSet)
  }

  func testInit_SetsEmptyCalibration() {
    XCTAssertEqual(viewModel.calibration.yesCount, 0)
    XCTAssertEqual(viewModel.calibration.interestLevel, .notSet)
  }

  func testInit_SetsLoadingStateFalse() {
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertFalse(viewModel.isSubmitting)
  }

  // MARK: - Load Form Data Tests

  func testLoadFormData_Success() async {
    // Given
    mockService.mockSchools = createMockSchools(count: 3)
    mockService.mockCoaches = createMockCoaches(count: 5)

    // When
    await viewModel.loadFormData()

    // Then
    XCTAssertEqual(viewModel.schools.count, 3)
    XCTAssertEqual(viewModel.allCoaches.count, 5)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoadFormData_ServiceError_ShowsError() async {
    // Given
    mockService.shouldSucceed = false

    // When
    await viewModel.loadFormData()

    // Then
    XCTAssertEqual(viewModel.schools.count, 0)
    XCTAssertEqual(viewModel.allCoaches.count, 0)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadFormData_SkipsDuplicateLoad() async {
    // Given
    mockService.mockSchools = createMockSchools(count: 2)

    // When (trigger load twice)
    await viewModel.loadFormData()
    let firstCount = viewModel.schools.count

    // Simulate already loading
    viewModel.isLoading = true
    await viewModel.loadFormData()

    // Then (second load skipped)
    XCTAssertEqual(viewModel.schools.count, firstCount)
  }

  // MARK: - School Coaches Filtering Tests

  func testSchoolCoaches_EmptyWhenNoSchoolSelected() {
    // Given
    viewModel.formState.schoolId = ""
    viewModel.allCoaches = createMockCoaches(count: 5)

    // Then
    XCTAssertEqual(viewModel.schoolCoaches.count, 0)
  }

  func testSchoolCoaches_FiltersCorrectly() {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.allCoaches = [
      createCoach(id: "c1", schoolId: "school1"),
      createCoach(id: "c2", schoolId: "school2"),
      createCoach(id: "c3", schoolId: "school1"),
      createCoach(id: "c4", schoolId: "school3")
    ]

    // Then
    XCTAssertEqual(viewModel.schoolCoaches.count, 2)
    XCTAssertTrue(viewModel.schoolCoaches.allSatisfy { $0.schoolId == "school1" })
  }

  // MARK: - Can Submit Tests

  func testCanSubmit_FalseWhenSchoolNotSelected() {
    // Given
    viewModel.formState.schoolId = ""
    viewModel.formState.type = .email

    // Then
    XCTAssertFalse(viewModel.canSubmit)
  }

  func testCanSubmit_FalseWhenTypeNotSelected() {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.formState.type = nil

    // Then
    XCTAssertFalse(viewModel.canSubmit)
  }

  func testCanSubmit_FalseWhenSubmitting() {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.formState.type = .email
    viewModel.isSubmitting = true

    // Then
    XCTAssertFalse(viewModel.canSubmit)
  }

  func testCanSubmit_TrueWhenValid() {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.formState.type = .email
    viewModel.isSubmitting = false

    // Then
    XCTAssertTrue(viewModel.canSubmit)
  }

  // MARK: - Form Validation Tests

  func testValidateForm_SchoolRequired() {
    // Given
    viewModel.formState.schoolId = ""
    viewModel.formState.type = .email

    // When
    let errors = viewModel.validateForm()

    // Then
    XCTAssertNotNil(errors["school"])
    XCTAssertTrue(errors["school"]?.contains("select a school") ?? false)
  }

  func testValidateForm_TypeRequired() {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.formState.type = nil

    // When
    let errors = viewModel.validateForm()

    // Then
    XCTAssertNotNil(errors["type"])
    XCTAssertTrue(errors["type"]?.contains("select an interaction type") ?? false)
  }

  func testValidateForm_SubjectMaxLength() {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.formState.type = .email
    viewModel.formState.subject = String(repeating: "a", count: 501)

    // When
    let errors = viewModel.validateForm()

    // Then
    XCTAssertNotNil(errors["subject"])
    XCTAssertTrue(errors["subject"]?.contains("500 characters") ?? false)
  }

  func testValidateForm_ContentMaxLength() {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.formState.type = .email
    viewModel.formState.content = String(repeating: "a", count: 10001)

    // When
    let errors = viewModel.validateForm()

    // Then
    XCTAssertNotNil(errors["content"])
    XCTAssertTrue(errors["content"]?.contains("10,000 characters") ?? false)
  }

  func testValidateForm_NoErrors_WhenValid() {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.formState.type = .email
    viewModel.formState.subject = "Short subject"
    viewModel.formState.content = "Valid content"

    // When
    let errors = viewModel.validateForm()

    // Then
    XCTAssertTrue(errors.isEmpty)
  }

  // MARK: - School Change Tests

  func testOnSchoolChange_ClearsCoachSelection() {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.formState.coachId = "coach1"

    // When
    viewModel.onSchoolChange()

    // Then
    XCTAssertNil(viewModel.formState.coachId)
  }

  // MARK: - Interest Calibration Tests

  func testOnDirectionOrSentimentChange_ResetsCalibration_WhenConditionsNotMet() {
    // Given
    viewModel.formState.direction = .inbound
    viewModel.formState.sentiment = .veryPositive
    viewModel.calibration.answers[0] = true
    viewModel.formState.interestLevel = .low

    // When (change to outbound)
    viewModel.formState.direction = .outbound
    viewModel.onDirectionOrSentimentChange()

    // Then
    XCTAssertTrue(viewModel.calibration.answers.allSatisfy { !$0 })
    XCTAssertEqual(viewModel.formState.interestLevel, .notSet)
  }

  func testOnDirectionOrSentimentChange_PreservesCalibration_WhenConditionsMet() {
    // Given
    viewModel.formState.direction = .inbound
    viewModel.formState.sentiment = .positive
    viewModel.calibration.answers[0] = true

    // When
    viewModel.onDirectionOrSentimentChange()

    // Then
    XCTAssertTrue(viewModel.calibration.answers[0])
  }

  func testOnCalibrationAnswerChange_UpdatesInterestLevel() {
    // Given
    viewModel.calibration.answers[0] = true
    viewModel.calibration.answers[1] = true

    // When
    viewModel.onCalibrationAnswerChange()

    // Then
    XCTAssertEqual(viewModel.formState.interestLevel, .medium)
  }

  // MARK: - Create New Coach Tests

  func testCreateNewCoach_Success() async {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.newCoachForm.firstName = "John"
    viewModel.newCoachForm.lastName = "Smith"
    viewModel.newCoachForm.role = .head

    let newCoach = createCoach(id: "new-coach", schoolId: "school1")
    mockService.mockCreatedCoach = newCoach

    // When
    let success = await viewModel.createNewCoach()

    // Then
    XCTAssertTrue(success)
    XCTAssertEqual(mockService.createCoachCallCount, 1)
    XCTAssertTrue(viewModel.allCoaches.contains { $0.id == "new-coach" })
    XCTAssertEqual(viewModel.formState.coachId, "new-coach")
    XCTAssertTrue(viewModel.newCoachForm.firstName.isEmpty)
  }

  func testCreateNewCoach_FailsWhenFormInvalid() async {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.newCoachForm.firstName = ""
    viewModel.newCoachForm.lastName = ""

    // When
    let success = await viewModel.createNewCoach()

    // Then
    XCTAssertFalse(success)
    XCTAssertEqual(mockService.createCoachCallCount, 0)
  }

  func testCreateNewCoach_FailsWhenNoSchoolSelected() async {
    // Given
    viewModel.formState.schoolId = ""
    viewModel.newCoachForm.firstName = "John"
    viewModel.newCoachForm.lastName = "Smith"

    // When
    let success = await viewModel.createNewCoach()

    // Then
    XCTAssertFalse(success)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage?.contains("select a school") ?? false)
  }

  func testCreateNewCoach_ServiceError_ShowsError() async {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.newCoachForm.firstName = "John"
    viewModel.newCoachForm.lastName = "Smith"
    mockService.shouldSucceed = false

    // When
    let success = await viewModel.createNewCoach()

    // Then
    XCTAssertFalse(success)
    XCTAssertNotNil(viewModel.errorMessage)
  }

  // MARK: - Other Coach Tests

  func testHandleOtherCoach_ClearsCoachId() {
    // Given
    viewModel.formState.coachId = "coach1"
    viewModel.otherCoachName = "Some Other Coach"

    // When
    viewModel.handleOtherCoach()

    // Then
    XCTAssertNil(viewModel.formState.coachId)
    XCTAssertFalse(viewModel.showOtherCoachSheet)
  }

  func testHandleOtherCoach_DoesNothingWhenNameEmpty() {
    // Given
    viewModel.formState.coachId = "coach1"
    viewModel.otherCoachName = ""

    // When
    viewModel.handleOtherCoach()

    // Then
    XCTAssertEqual(viewModel.formState.coachId, "coach1")
  }

  // MARK: - Submit Interaction Tests

  func testSubmitInteraction_Success() async {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.formState.type = .email
    viewModel.formState.subject = "Test Subject"
    viewModel.formState.content = "Test Content"
    viewModel.formState.direction = .outbound
    viewModel.formState.sentiment = .positive

    let createdInteraction = createInteraction(id: "new-1")
    mockService.mockCreatedInteraction = createdInteraction

    // When
    let success = await viewModel.submitInteraction()

    // Then
    XCTAssertTrue(success)
    XCTAssertEqual(mockService.createInteractionCallCount, 1)
    XCTAssertFalse(viewModel.isSubmitting)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testSubmitInteraction_FailsWhenFormInvalid() async {
    // Given
    viewModel.formState.schoolId = ""
    viewModel.formState.type = nil

    // When
    let success = await viewModel.submitInteraction()

    // Then
    XCTAssertFalse(success)
    XCTAssertEqual(mockService.createInteractionCallCount, 0)
  }

  func testSubmitInteraction_FailsWhenValidationErrors() async {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.formState.type = .email
    viewModel.formState.subject = String(repeating: "a", count: 501)

    // When
    let success = await viewModel.submitInteraction()

    // Then
    XCTAssertFalse(success)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertEqual(mockService.createInteractionCallCount, 0)
  }

  func testSubmitInteraction_AppendsInterestLevelToContent() async {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.formState.type = .email
    viewModel.formState.direction = .inbound
    viewModel.formState.sentiment = .veryPositive
    viewModel.formState.content = "Original content"
    viewModel.calibration.answers = [true, true, true, true, true, true]
    viewModel.onCalibrationAnswerChange()

    // When
    let success = await viewModel.submitInteraction()

    // Then
    XCTAssertTrue(success)
    XCTAssertTrue(mockService.lastCreatedInteractionRequest?.content?.contains("[Coach Interest Level: HIGH]") ?? false)
  }

  func testSubmitInteraction_AppendsOtherCoachName() async {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.formState.type = .email
    viewModel.formState.coachId = nil
    viewModel.otherCoachName = "Coach Other"
    viewModel.formState.content = "Original content"

    // When
    let success = await viewModel.submitInteraction()

    // Then
    XCTAssertTrue(success)
    XCTAssertTrue(mockService.lastCreatedInteractionRequest?.content?.contains("[Coach: Coach Other]") ?? false)
  }

  func testSubmitInteraction_ServiceError_ShowsError() async {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.formState.type = .email
    mockService.shouldSucceed = false

    // When
    let success = await viewModel.submitInteraction()

    // Then
    XCTAssertFalse(success)
    XCTAssertNotNil(viewModel.errorMessage)
  }

  // MARK: - Reset Tests

  func testReset_ClearsAllState() {
    // Given
    viewModel.formState.schoolId = "school1"
    viewModel.formState.type = .email
    viewModel.calibration.answers[0] = true
    viewModel.otherCoachName = "Test"
    viewModel.errorMessage = "Error"

    // When
    viewModel.reset()

    // Then
    XCTAssertTrue(viewModel.formState.schoolId.isEmpty)
    XCTAssertNil(viewModel.formState.type)
    XCTAssertTrue(viewModel.calibration.answers.allSatisfy { !$0 })
    XCTAssertTrue(viewModel.otherCoachName.isEmpty)
    XCTAssertNil(viewModel.errorMessage)
  }

  // MARK: - Computed Properties Tests

  func testPageTitle() {
    XCTAssertEqual(viewModel.pageTitle, "Log Interaction")
  }

  // MARK: - Auto-advance toast (contactedAdvanceMessage)

  private func primeValidForm(schoolId: String) {
    viewModel.formState.schoolId = schoolId
    viewModel.formState.type = .email
    viewModel.formState.direction = .outbound
    viewModel.formState.content = "Test"
    mockService.mockCreatedInteraction = createInteraction(id: "new-1")
  }

  func testSubmitInteraction_setsAdvanceMessage_whenSchoolPreContact() async {
    viewModel.schools = [createSchool(id: "school1", name: "School 1", status: "researching")]
    primeValidForm(schoolId: "school1")

    let success = await viewModel.submitInteraction()

    XCTAssertTrue(success)
    XCTAssertEqual(viewModel.contactedAdvanceMessage, "School 1 moved to Contacted")
  }

  func testSubmitInteraction_noAdvanceMessage_whenSchoolAlreadyContacted() async {
    viewModel.schools = [createSchool(id: "school1", name: "School 1", status: "contacted")]
    primeValidForm(schoolId: "school1")

    let success = await viewModel.submitInteraction()

    XCTAssertTrue(success)
    XCTAssertNil(viewModel.contactedAdvanceMessage)
  }

  func testSubmitInteraction_noAdvanceMessage_whenSchoolPastContacted() async {
    viewModel.schools = [createSchool(id: "school1", name: "School 1", status: "visiting")]
    primeValidForm(schoolId: "school1")

    let success = await viewModel.submitInteraction()

    XCTAssertTrue(success)
    XCTAssertNil(viewModel.contactedAdvanceMessage)
  }

  func testSubmitButtonTitle_Default() {
    viewModel.isSubmitting = false
    XCTAssertEqual(viewModel.submitButtonTitle, "Log Interaction")
  }

  func testSubmitButtonTitle_Submitting() {
    viewModel.isSubmitting = true
    XCTAssertEqual(viewModel.submitButtonTitle, "Logging...")
  }

  // MARK: - Helper Methods

  private func createMockSchools(count: Int) -> [School] {
    (0..<count).map { index in
      createSchool(id: "school\(index)", name: "School \(index)")
    }
  }

  private func createSchool(id: String, name: String, status: String = "researching") -> School {
    School(
      id: id,
      userId: "user1",
      name: name,
      location: nil,
      city: nil,
      state: nil,
      division: nil,
      conference: nil,
      ranking: nil,
      isFavorite: false,
      website: nil,
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: status,
      statusChangedAt: nil,
      notes: nil,
      pros: [],
      cons: [],
      offerDetails: nil,
      academicInfo: nil,
      amenities: nil,
      coachingPhilosophy: nil,
      coachingStyle: nil,
      recruitingApproach: nil,
      communicationStyle: nil,
      successMetrics: nil,
      familyUnitId: "family1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "",
      updatedAt: ""
    )
  }

  private func createMockCoaches(count: Int) -> [Coach] {
    (0..<count).map { index in
      createCoach(id: "coach\(index)", schoolId: "school\(index % 3)")
    }
  }

  private func createCoach(id: String, schoolId: String) -> Coach {
    Coach(
      id: id,
      firstName: "First",
      lastName: "Last",
      email: nil,
      phone: nil,
      position: "Assistant",
      schoolId: schoolId,
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      lastContactDate: nil,
      createdAt: ISO8601DateFormatter().string(from: Date()),
      updatedAt: ISO8601DateFormatter().string(from: Date())
    )
  }

  private func makeDraft(
    id: String = "draft-1",
    matchedSchoolId: String? = "school1",
    matchedCoachId: String? = nil,
    subject: String? = "Great game",
    bodyText: String? = "Loved watching you play",
    occurredAt: String = "2026-09-01T12:00:00.000Z",
    senderName: String? = "Coach Smith",
    senderEmail: String? = "coach@school.edu"
  ) -> InboundEmailDraft {
    InboundEmailDraft(
      id: id, familyUnitId: "family1", rawEmailId: nil, matchedCoachId: matchedCoachId,
      matchedSchoolId: matchedSchoolId, senderName: senderName, senderEmail: senderEmail,
      subject: subject, bodyText: bodyText, occurredAt: occurredAt,
      status: "pending", confirmedInteractionId: nil, createdAt: occurredAt
    )
  }

  private func makeDraftConfirmViewModel(
    draft: InboundEmailDraft,
    draftsAPIService: MockInboundDraftsAPIService
  ) -> AddInteractionViewModel {
    let mockAuth = MockAuthManager()
    mockAuth.setMockSession(Session(
      accessToken: "test-token", tokenType: "bearer", expiresIn: 3600,
      expiresAt: 9_999_999_999, refreshToken: "refresh",
      user: User(id: "user1", email: "a@b.com", emailConfirmedAt: nil, phone: nil, fullName: nil, createdAt: "", updatedAt: "", role: nil, dateOfBirth: nil)
    ))
    return AddInteractionViewModel(
      interactionsService: mockService,
      familyUnitId: "family1",
      userId: "user1",
      draftToConfirm: draft,
      draftsAPIService: draftsAPIService,
      authManager: mockAuth
    )
  }

  // MARK: - Draft review/confirm (#113 parity w/ web #678)

  func testPageTitle_ReviewingDraft() {
    let draftsAPI = MockInboundDraftsAPIService()
    let viewModel = makeDraftConfirmViewModel(draft: makeDraft(), draftsAPIService: draftsAPI)

    XCTAssertEqual(viewModel.pageTitle, "Review Coach Email")
  }

  func testLoadFormData_PrefillsFromMatchedDraft() async {
    mockService.mockSchools = [createSchool(id: "school1", name: "School 1")]
    let draft = makeDraft(matchedSchoolId: "school1", matchedCoachId: "coach1")
    let draftsAPI = MockInboundDraftsAPIService()
    let viewModel = makeDraftConfirmViewModel(draft: draft, draftsAPIService: draftsAPI)

    await viewModel.loadFormData()

    XCTAssertEqual(viewModel.formState.schoolId, "school1")
    XCTAssertEqual(viewModel.formState.coachId, "coach1")
    XCTAssertEqual(viewModel.formState.type, .email)
    XCTAssertEqual(viewModel.formState.direction, .inbound)
    XCTAssertEqual(viewModel.formState.subject, "Great game")
    XCTAssertEqual(viewModel.formState.content, "Loved watching you play")
  }

  func testLoadFormData_LeavesSchoolBlankWhenDraftUnmatched() async {
    mockService.mockSchools = [createSchool(id: "school1", name: "School 1")]
    let draft = makeDraft(matchedSchoolId: nil)
    let draftsAPI = MockInboundDraftsAPIService()
    let viewModel = makeDraftConfirmViewModel(draft: draft, draftsAPIService: draftsAPI)

    await viewModel.loadFormData()

    XCTAssertTrue(viewModel.formState.schoolId.isEmpty)
  }

  // MARK: - Unmatched coach/school resolution from draft review (#125, parity w/ web #675)

  func testLoadFormData_PrefillsNewCoachFormFromDraftSender() async {
    mockService.mockSchools = [createSchool(id: "school1", name: "School 1")]
    let draft = makeDraft(senderName: "Mark Royer", senderEmail: "mroyer@osu.edu")
    let draftsAPI = MockInboundDraftsAPIService()
    let viewModel = makeDraftConfirmViewModel(draft: draft, draftsAPIService: draftsAPI)

    await viewModel.loadFormData()

    XCTAssertEqual(viewModel.newCoachForm.firstName, "Mark")
    XCTAssertEqual(viewModel.newCoachForm.lastName, "Royer")
    XCTAssertEqual(viewModel.newCoachForm.email, "mroyer@osu.edu")
  }

  func testLoadFormData_NewCoachFormBlank_WhenNotReviewingDraft() async {
    mockService.mockSchools = [createSchool(id: "school1", name: "School 1")]

    await viewModel.loadFormData()

    XCTAssertTrue(viewModel.newCoachForm.firstName.isEmpty)
    XCTAssertTrue(viewModel.newCoachForm.email.isEmpty)
  }

  func testCreateNewCoach_PassesTrimmedEmail() async {
    viewModel.formState.schoolId = "school1"
    viewModel.newCoachForm.firstName = "John"
    viewModel.newCoachForm.lastName = "Smith"
    viewModel.newCoachForm.email = "  john@school.edu  "
    mockService.mockCreatedCoach = createCoach(id: "new-coach", schoolId: "school1")

    let success = await viewModel.createNewCoach()

    XCTAssertTrue(success)
    XCTAssertEqual(mockService.lastCreatedCoachRequest?.email, "john@school.edu")
  }

  func testCreateNewCoach_SendsNilEmail_WhenBlank() async {
    viewModel.formState.schoolId = "school1"
    viewModel.newCoachForm.firstName = "John"
    viewModel.newCoachForm.lastName = "Smith"
    mockService.mockCreatedCoach = createCoach(id: "new-coach", schoolId: "school1")

    let success = await viewModel.createNewCoach()

    XCTAssertTrue(success)
    XCTAssertNil(mockService.lastCreatedCoachRequest?.email)
  }

  func testSchoolWebsitePrefill_DerivesDomainFromSenderEmail() async {
    mockService.mockSchools = [createSchool(id: "school1", name: "School 1")]
    let draft = makeDraft(senderEmail: "mroyer@osu.edu")
    let draftsAPI = MockInboundDraftsAPIService()
    let viewModel = makeDraftConfirmViewModel(draft: draft, draftsAPIService: draftsAPI)

    await viewModel.loadFormData()

    XCTAssertEqual(viewModel.schoolWebsitePrefill, "https://osu.edu")
  }

  func testSchoolWebsitePrefill_NilWhenNoAtSign() async {
    mockService.mockSchools = [createSchool(id: "school1", name: "School 1")]
    let draft = makeDraft(senderEmail: "not-an-email")
    let draftsAPI = MockInboundDraftsAPIService()
    let viewModel = makeDraftConfirmViewModel(draft: draft, draftsAPIService: draftsAPI)

    await viewModel.loadFormData()

    XCTAssertNil(viewModel.schoolWebsitePrefill)
  }

  func testSchoolWebsitePrefill_NilWhenNotReviewingDraft() async {
    mockService.mockSchools = [createSchool(id: "school1", name: "School 1")]

    await viewModel.loadFormData()

    XCTAssertNil(viewModel.schoolWebsitePrefill)
  }

  func testSelectNewlyCreatedSchool_SetsSchoolIdAndAppendsToList() {
    let newSchool = createSchool(id: "new-school", name: "New School")

    viewModel.selectNewlyCreatedSchool(newSchool)

    XCTAssertEqual(viewModel.formState.schoolId, "new-school")
    XCTAssertTrue(viewModel.schools.contains { $0.id == "new-school" })
  }

  func testSubmitInteraction_ConfirmsDraftInsteadOfCreatingDirectly() async {
    mockService.mockSchools = [createSchool(id: "school1", name: "School 1")]
    let draft = makeDraft(matchedSchoolId: "school1")
    let draftsAPI = MockInboundDraftsAPIService()
    let viewModel = makeDraftConfirmViewModel(draft: draft, draftsAPIService: draftsAPI)
    await viewModel.loadFormData()
    viewModel.formState.subject = "Edited subject"
    viewModel.formState.coachId = nil

    let success = await viewModel.submitInteraction()

    XCTAssertTrue(success)
    XCTAssertEqual(draftsAPI.confirmCallCount, 1)
    XCTAssertEqual(mockService.createInteractionCallCount, 0)
    XCTAssertEqual(draftsAPI.lastConfirmedDraftId, draft.id)
    XCTAssertEqual(draftsAPI.lastConfirmedSchoolId, "school1")
    XCTAssertNil(draftsAPI.lastConfirmedCoachId)
    XCTAssertEqual(draftsAPI.lastConfirmedType, .email)
    XCTAssertEqual(draftsAPI.lastConfirmedDirection, .inbound)
    XCTAssertEqual(draftsAPI.lastConfirmedSubject, "Edited subject")
  }

  func testSubmitInteraction_DraftConfirmFailure_ShowsError() async {
    mockService.mockSchools = [createSchool(id: "school1", name: "School 1")]
    let draft = makeDraft(matchedSchoolId: "school1")
    let draftsAPI = MockInboundDraftsAPIService()
    draftsAPI.errorToThrow = InboundDraftsAPIError.server(500)
    let viewModel = makeDraftConfirmViewModel(draft: draft, draftsAPIService: draftsAPI)
    await viewModel.loadFormData()

    let success = await viewModel.submitInteraction()

    XCTAssertFalse(success)
    XCTAssertNotNil(viewModel.errorMessage)
  }

  private func createInteraction(id: String) -> Interaction {
    Interaction(
      id: id,
      type: .email,
      direction: .outbound,
      schoolId: "school1",
      coachId: "coach1",
      subject: "Subject",
      content: "Content",
      sentiment: nil,
      occurredAt: ISO8601DateFormatter().string(from: Date()),
      loggedBy: "user1",
      attachments: nil,
      familyUnitId: "family1",
      createdAt: ISO8601DateFormatter().string(from: Date()),
      updatedAt: nil
    )
  }
}
