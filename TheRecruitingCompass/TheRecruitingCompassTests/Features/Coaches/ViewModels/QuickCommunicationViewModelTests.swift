import XCTest
@testable import TheRecruitingCompass

@MainActor
final class QuickCommunicationViewModelTests: XCTestCase {
  nonisolated deinit {}

  var viewModel: QuickCommunicationViewModel!
  var mockService: MockCommunicationTemplatesService!

  override func setUp() {
    mockService = MockCommunicationTemplatesService()
    viewModel = QuickCommunicationViewModel(
      coach: makeCoach(),
      schoolName: "Test University",
      templatesService: mockService
    )
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
  }

  // MARK: - Initial State

  func testRecipientLine_combinesNameAndRole() {
    XCTAssertEqual(viewModel.recipientLine, "Jane Smith – Assistant Coach")
  }

  // MARK: - loadTemplates

  func testLoadTemplates_success_populatesTemplates() async {
    mockService.mockTemplates = [
      makeTemplate(id: "t1", type: .email),
      makeTemplate(id: "t2", type: .message)
    ]

    await viewModel.loadTemplates()

    XCTAssertEqual(viewModel.templates.count, 2)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertEqual(mockService.fetchTemplatesCallCount, 1)
  }

  func testLoadTemplates_error_setsErrorMessage() async {
    mockService.shouldThrowOnFetch = true

    await viewModel.loadTemplates()

    XCTAssertEqual(viewModel.errorMessage, "Failed to load templates. Please try again.")
    XCTAssertTrue(viewModel.templates.isEmpty)
  }

  func testLoadTemplates_selectedTemplateNoLongerPresent_clearsSelection() async {
    let stale = makeTemplate(id: "stale", type: .email)
    viewModel.selectTemplate(stale)
    mockService.mockTemplates = [makeTemplate(id: "current", type: .email)]

    await viewModel.loadTemplates()

    XCTAssertNil(viewModel.selectedTemplate)
  }

  func testLoadTemplates_selectedTemplateStillPresent_keepsSelection() async {
    let template = makeTemplate(id: "t1", type: .email)
    mockService.mockTemplates = [template]
    await viewModel.loadTemplates()
    viewModel.selectTemplate(template)

    await viewModel.loadTemplates()

    XCTAssertEqual(viewModel.selectedTemplate?.id, "t1")
  }

  // MARK: - Filtered templates

  func testEmailTemplates_filtersToEmailType() async {
    mockService.mockTemplates = [
      makeTemplate(id: "e1", type: .email),
      makeTemplate(id: "s1", type: .message),
      makeTemplate(id: "e2", type: .email)
    ]
    await viewModel.loadTemplates()

    XCTAssertEqual(viewModel.emailTemplates.map(\.id).sorted(), ["e1", "e2"])
  }

  func testTextTemplates_filtersToTextType() async {
    mockService.mockTemplates = [
      makeTemplate(id: "e1", type: .email),
      makeTemplate(id: "s1", type: .message)
    ]
    await viewModel.loadTemplates()

    XCTAssertEqual(viewModel.textTemplates.map(\.id), ["s1"])
  }

  // MARK: - filledBody (variable substitution)

  func testFilledBody_noSelectedTemplate_returnsEmpty() {
    XCTAssertEqual(viewModel.filledBody, "")
  }

  func testFilledBody_substitutesCoachAndSchoolName() {
    viewModel.selectTemplate(makeTemplate(id: "t1", type: .email, body: "Hi {{coach_name}}, from {{school_name}}."))

    XCTAssertEqual(viewModel.filledBody, "Hi Jane Smith, from Test University.")
  }

  func testFilledBody_noSchoolName_fallsBackToPlaceholder() {
    let sut = QuickCommunicationViewModel(coach: makeCoach(), schoolName: nil, templatesService: mockService)
    sut.selectTemplate(makeTemplate(id: "t1", type: .email, body: "From {{school_name}}."))

    XCTAssertEqual(sut.filledBody, "From [School Name].")
  }

  // MARK: - mailtoURL

  func testMailtoURL_noEmail_returnsNil() {
    let sut = QuickCommunicationViewModel(coach: makeCoach(email: nil), schoolName: nil, templatesService: mockService)
    XCTAssertNil(sut.mailtoURL())
  }

  func testMailtoURL_withEmail_buildsURL() {
    let url = viewModel.mailtoURL()
    XCTAssertEqual(url?.scheme, "mailto")
    XCTAssertTrue(url?.absoluteString.contains("coach@example.com") ?? false)
  }

  func testMailtoURL_withBody_includesBodyQueryItem() {
    viewModel.selectTemplate(makeTemplate(id: "t1", type: .email, body: "Hello {{coach_name}}"))

    let url = viewModel.mailtoURL()
    let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
    XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "body" })?.value, "Hello Jane Smith")
  }

  func testMailtoURL_truncatesLongBody() {
    let longBody = String(repeating: "a", count: 2000)
    viewModel.selectTemplate(makeTemplate(id: "t1", type: .email, body: longBody))

    let url = viewModel.mailtoURL()
    let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
    let bodyValue = components?.queryItems?.first(where: { $0.name == "body" })?.value ?? ""
    XCTAssertLessThan(bodyValue.count, 2000)
    XCTAssertTrue(bodyValue.contains("[Message truncated"))
  }

  // MARK: - smsURL

  func testSmsURL_noPhone_returnsNil() {
    let sut = QuickCommunicationViewModel(coach: makeCoach(phone: nil), schoolName: nil, templatesService: mockService)
    XCTAssertNil(sut.smsURL())
  }

  func testSmsURL_stripsNonNumericCharacters() {
    let sut = QuickCommunicationViewModel(coach: makeCoach(phone: "(555) 123-4567"), schoolName: nil, templatesService: mockService)
    XCTAssertEqual(sut.smsURL()?.absoluteString, "sms:5551234567")
  }

  func testSmsURL_emptyAfterStripping_returnsNil() {
    let sut = QuickCommunicationViewModel(coach: makeCoach(phone: "()- "), schoolName: nil, templatesService: mockService)
    XCTAssertNil(sut.smsURL())
  }

  // MARK: - logSend (log on confirmed send only)

  /// The View calls `logSend` ONLY on a confirmed composer `.sent`; `.cancelled`/`.saved`/`.failed`
  /// and the no-account fallback never reach it (view-level `guard result == .sent`). These tests
  /// verify the ViewModel side: a confirmed send logs exactly one outbound interaction + stamps the
  /// coach, and a missing user/family context logs nothing.

  func testLogSend_email_createsOneOutboundInteractionWithEmailType() async {
    let interactions = MockInteractionsService()
    let coaches = MockCoachesService()
    coaches.stubbedUpdatedCoach = makeCoach()
    let sut = makeLoggingSut(interactions: interactions, coaches: coaches)

    await sut.logSend(.email)

    XCTAssertEqual(interactions.createInteractionCallCount, 1)
    XCTAssertEqual(interactions.lastCreatedInteractionRequest?.type, "email")
    XCTAssertEqual(interactions.lastCreatedInteractionRequest?.direction, "outbound")
    XCTAssertEqual(interactions.lastCreatedInteractionRequest?.coachId, "coach-1")
    XCTAssertEqual(interactions.lastCreatedInteractionRequest?.loggedBy, "user-1")
    XCTAssertEqual(interactions.lastCreatedInteractionRequest?.familyUnitId, "family-1")
    XCTAssertTrue(sut.didLogSend)
    XCTAssertEqual(sut.successMessage, "Logged email to Coach Jane Smith.")
    XCTAssertNil(sut.errorMessage)
  }

  func testLogSend_text_createsInteractionWithTextType() async {
    let interactions = MockInteractionsService()
    let coaches = MockCoachesService()
    coaches.stubbedUpdatedCoach = makeCoach()
    let sut = makeLoggingSut(interactions: interactions, coaches: coaches)

    await sut.logSend(.text)

    XCTAssertEqual(interactions.createInteractionCallCount, 1)
    XCTAssertEqual(interactions.lastCreatedInteractionRequest?.type, "text")
    XCTAssertEqual(sut.successMessage, "Logged text to Coach Jane Smith.")
  }

  func testLogSend_stampsLastContactDateOnce() async {
    let interactions = MockInteractionsService()
    let coaches = MockCoachesService()
    coaches.stubbedUpdatedCoach = makeCoach()
    let sut = makeLoggingSut(interactions: interactions, coaches: coaches)

    await sut.logSend(.email)

    XCTAssertEqual(coaches.updateCoachCallCount, 1)
    XCTAssertEqual(coaches.lastUpdateCoachId, "coach-1")
    XCTAssertNotNil(coaches.lastUpdateCoachUpdates?.lastContactDate)
    XCTAssertNil(coaches.lastUpdateCoachUpdates?.notes)
    XCTAssertNil(coaches.lastUpdateCoachUpdates?.nextContactDate)
  }

  func testLogSend_missingContext_logsNothing() async {
    let interactions = MockInteractionsService()
    let coaches = MockCoachesService()
    // No loggedBy / familyUnitId injected.
    let sut = QuickCommunicationViewModel(
      coach: makeCoach(),
      schoolName: "Test University",
      templatesService: mockService,
      interactionsService: interactions,
      coachesService: coaches
    )

    await sut.logSend(.email)

    XCTAssertEqual(interactions.createInteractionCallCount, 0)
    XCTAssertEqual(coaches.updateCoachCallCount, 0)
    XCTAssertFalse(sut.didLogSend)
    XCTAssertEqual(sut.errorMessage, "Message sent, but logging it failed.")
  }

  func testLogSend_createInteractionFails_setsErrorAndDoesNotConfirm() async {
    let interactions = MockInteractionsService()
    interactions.shouldSucceed = false
    let coaches = MockCoachesService()
    let sut = makeLoggingSut(interactions: interactions, coaches: coaches)

    await sut.logSend(.email)

    XCTAssertFalse(sut.didLogSend)
    XCTAssertNil(sut.successMessage)
    XCTAssertEqual(coaches.updateCoachCallCount, 0)
    XCTAssertEqual(sut.errorMessage, "Message sent, but logging it failed.")
  }

  private func makeLoggingSut(
    interactions: MockInteractionsService,
    coaches: MockCoachesService
  ) -> QuickCommunicationViewModel {
    let sut = QuickCommunicationViewModel(
      coach: makeCoach(),
      schoolName: "Test University",
      templatesService: mockService,
      interactionsService: interactions,
      coachesService: coaches,
      loggedBy: "user-1",
      familyUnitId: "family-1"
    )
    return sut
  }

  // MARK: - Helpers

  private func makeCoach(email: String? = "coach@example.com", phone: String? = "555-123-4567") -> Coach {
    Coach(
      id: "coach-1",
      firstName: "Jane",
      lastName: "Smith",
      email: email,
      phone: phone,
      position: "assistant",
      schoolId: "school-1",
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      responsivenessScore: 0,
      lastContactDate: nil,
      nextContactDate: nil,
      followUpThresholdDays: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  private func makeTemplate(id: String, type: TemplateType, body: String = "Hi {{coach_name}}") -> CommunicationTemplate {
    CommunicationTemplate(
      id: id,
      userId: "user-1",
      name: "Template \(id)",
      type: type,
      body: body,
      variables: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }
}
