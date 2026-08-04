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
      makeTemplate(id: "t2", type: .text)
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
      makeTemplate(id: "s1", type: .text),
      makeTemplate(id: "e2", type: .email)
    ]
    await viewModel.loadTemplates()

    XCTAssertEqual(viewModel.emailTemplates.map(\.id).sorted(), ["e1", "e2"])
  }

  func testTextTemplates_filtersToTextType() async {
    mockService.mockTemplates = [
      makeTemplate(id: "e1", type: .email),
      makeTemplate(id: "s1", type: .text)
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
