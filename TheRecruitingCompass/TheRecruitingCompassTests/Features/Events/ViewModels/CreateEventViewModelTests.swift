import XCTest
@testable import TheRecruitingCompass

@MainActor
final class CreateEventViewModelTests: XCTestCase {
  nonisolated deinit {}

  private var sut: CreateEventViewModel!
  private var mockService: MockEventsService!

  override func setUp() {
    super.setUp()
    mockService = MockEventsService()
    sut = CreateEventViewModel(eventsService: mockService, userId: "test-user-id")
  }

  override func tearDown() {
    sut = nil
    mockService = nil
    super.tearDown()
  }

  // MARK: - Helpers

  private func date(_ string: String) -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: string)!
  }

  private func time(_ string: String) -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "HH:mm"
    return f.date(from: string)!
  }

  // MARK: - Validation Tests

  func testValidateForm_withRequiredFields_passes() {
    sut.formData.type = .showcase
    sut.formData.name = "Spring Showcase"
    sut.formData.startDate = date("2026-04-15")

    let isValid = sut.validateForm()

    XCTAssertTrue(isValid)
    XCTAssertTrue(sut.validationErrors.isEmpty)
  }

  func testValidateForm_missingType_failsWithError() {
    sut.formData.type = nil
    sut.formData.name = "Spring Showcase"
    sut.formData.startDate = date("2026-04-15")

    let isValid = sut.validateForm()

    XCTAssertFalse(isValid)
    XCTAssertNotNil(sut.validationErrors["type"])
  }

  func testValidateForm_emptyName_failsWithError() {
    sut.formData.type = .showcase
    sut.formData.name = ""
    sut.formData.startDate = date("2026-04-15")

    let isValid = sut.validateForm()

    XCTAssertFalse(isValid)
    XCTAssertNotNil(sut.validationErrors["name"])
  }

  func testValidateForm_whitespaceOnlyName_failsWithError() {
    sut.formData.type = .showcase
    sut.formData.name = "   "
    sut.formData.startDate = date("2026-04-15")

    let isValid = sut.validateForm()

    XCTAssertFalse(isValid)
    XCTAssertNotNil(sut.validationErrors["name"])
  }

  func testValidateForm_emptyStartDate_failsWithError() {
    sut.formData.type = .showcase
    sut.formData.name = "Spring Showcase"
    sut.formData.startDate = nil

    let isValid = sut.validateForm()

    XCTAssertFalse(isValid)
    XCTAssertNotNil(sut.validationErrors["startDate"])
  }

  func testValidateForm_endDateBeforeStartDate_failsWithError() {
    sut.formData.type = .showcase
    sut.formData.name = "Spring Showcase"
    sut.formData.startDate = date("2026-04-15")
    sut.formData.endDate = date("2026-04-14")

    let isValid = sut.validateForm()

    XCTAssertFalse(isValid)
    XCTAssertNotNil(sut.validationErrors["endDate"])
  }

  func testValidateForm_endDateEqualsStartDate_passes() {
    sut.formData.type = .showcase
    sut.formData.name = "Spring Showcase"
    sut.formData.startDate = date("2026-04-15")
    sut.formData.endDate = date("2026-04-15")

    let isValid = sut.validateForm()

    XCTAssertTrue(isValid)
    XCTAssertNil(sut.validationErrors["endDate"])
  }

  func testValidateForm_endDateAfterStartDate_passes() {
    sut.formData.type = .camp
    sut.formData.name = "Summer Camp"
    sut.formData.startDate = date("2026-06-01")
    sut.formData.endDate = date("2026-06-05")

    let isValid = sut.validateForm()

    XCTAssertTrue(isValid)
  }

  func testValidateForm_emptyEndDate_passes() {
    sut.formData.type = .showcase
    sut.formData.name = "Spring Showcase"
    sut.formData.startDate = date("2026-04-15")
    sut.formData.endDate = nil

    let isValid = sut.validateForm()

    XCTAssertTrue(isValid)
  }

  func testValidateForm_validURL_passes() {
    sut.formData.type = .showcase
    sut.formData.name = "Spring Showcase"
    sut.formData.startDate = date("2026-04-15")
    sut.formData.url = "https://example.com/event"

    let isValid = sut.validateForm()

    XCTAssertTrue(isValid)
    XCTAssertNil(sut.validationErrors["url"])
  }

  func testValidateForm_httpURL_passes() {
    sut.formData.type = .showcase
    sut.formData.name = "Spring Showcase"
    sut.formData.startDate = date("2026-04-15")
    sut.formData.url = "http://example.com"

    let isValid = sut.validateForm()

    XCTAssertTrue(isValid)
    XCTAssertNil(sut.validationErrors["url"])
  }

  func testValidateForm_invalidURL_noScheme_failsWithError() {
    sut.formData.type = .showcase
    sut.formData.name = "Spring Showcase"
    sut.formData.startDate = date("2026-04-15")
    sut.formData.url = "not-a-url"

    let isValid = sut.validateForm()

    XCTAssertFalse(isValid)
    XCTAssertNotNil(sut.validationErrors["url"])
  }

  func testValidateForm_invalidURL_missingScheme_failsWithError() {
    sut.formData.type = .showcase
    sut.formData.name = "Spring Showcase"
    sut.formData.startDate = date("2026-04-15")
    sut.formData.url = "example.com"

    let isValid = sut.validateForm()

    XCTAssertFalse(isValid)
    XCTAssertNotNil(sut.validationErrors["url"])
  }

  func testValidateForm_emptyURL_passes() {
    sut.formData.type = .showcase
    sut.formData.name = "Spring Showcase"
    sut.formData.startDate = date("2026-04-15")
    sut.formData.url = ""

    let isValid = sut.validateForm()

    XCTAssertTrue(isValid)
    XCTAssertNil(sut.validationErrors["url"])
  }

  func testValidateForm_multipleErrors_reportsAll() {
    sut.formData.type = nil
    sut.formData.name = ""
    sut.formData.startDate = nil

    let isValid = sut.validateForm()

    XCTAssertFalse(isValid)
    XCTAssertGreaterThanOrEqual(sut.validationErrors.count, 3)
  }

  // MARK: - Date Auto-Population Tests

  func testEndDateAutoPopulates_whenStartDateSet_andEndDateIsEmpty() {
    sut.formData.endDate = nil

    sut.handleStartDateChanged(date("2026-04-15"))

    XCTAssertEqual(sut.formData.endDate, date("2026-04-15"))
  }

  func testEndDateDoesNotOverwrite_whenEndDateAlreadySet() {
    sut.formData.endDate = date("2026-04-20")

    sut.handleStartDateChanged(date("2026-04-15"))

    XCTAssertEqual(sut.formData.endDate, date("2026-04-20"))
  }

  func testEndTimeAutoPopulates_plusOneHour_whenStartTimeSet() {
    sut.formData.endTime = nil
    let startTime = time("09:00")

    sut.handleStartTimeChanged(startTime)

    let expectedEnd = Calendar.current.date(byAdding: .hour, value: 1, to: startTime)
    XCTAssertEqual(sut.formData.endTime, expectedEnd)
  }

  func testEndTimeAutoPopulates_handlesEndOfDay_wraps() {
    sut.formData.endTime = nil
    let startTime = time("23:30")

    sut.handleStartTimeChanged(startTime)

    let expectedEnd = Calendar.current.date(byAdding: .hour, value: 1, to: startTime)
    XCTAssertEqual(sut.formData.endTime, expectedEnd)
  }

  func testEndTimeDoesNotOverwrite_whenEndTimeAlreadySet() {
    sut.formData.endTime = time("17:00")

    sut.handleStartTimeChanged(time("09:00"))

    XCTAssertEqual(sut.formData.endTime, time("17:00"))
  }

  func testEndTimeAutoPopulates_preservesMinutes() {
    sut.formData.endTime = nil
    let startTime = time("14:45")

    sut.handleStartTimeChanged(startTime)

    let expectedEnd = Calendar.current.date(byAdding: .hour, value: 1, to: startTime)
    XCTAssertEqual(sut.formData.endTime, expectedEnd)
  }

  // MARK: - School Selection Modal Tests

  func testHandleSchoolSelection_other_showsOtherModal() {
    sut.handleSchoolSelection("other")

    XCTAssertTrue(sut.showOtherSchoolModal)
    XCTAssertFalse(sut.showAddSchoolModal)
  }

  func testHandleSchoolSelection_addNew_showsAddSchoolModal() {
    sut.handleSchoolSelection("add_new")

    XCTAssertTrue(sut.showAddSchoolModal)
    XCTAssertFalse(sut.showOtherSchoolModal)
  }

  func testHandleSchoolSelection_schoolId_setsSchoolId() {
    sut.handleSchoolSelection("school-123")

    XCTAssertEqual(sut.formData.schoolId, "school-123")
    XCTAssertFalse(sut.showOtherSchoolModal)
    XCTAssertFalse(sut.showAddSchoolModal)
  }

  func testHandleSchoolSelection_none_clearsSchoolId() {
    sut.formData.schoolId = "school-123"

    sut.handleSchoolSelection(nil)

    XCTAssertNil(sut.formData.schoolId)
  }

  func testHandleOtherSchool_withName_closesModal() {
    sut.showOtherSchoolModal = true
    sut.otherSchoolName = "Some Unlisted School"

    sut.handleOtherSchool()

    XCTAssertFalse(sut.showOtherSchoolModal)
  }

  func testHandleOtherSchool_emptyName_doesNotClose() {
    sut.showOtherSchoolModal = true
    sut.otherSchoolName = ""

    sut.handleOtherSchool()

    XCTAssertTrue(sut.showOtherSchoolModal)
  }

  func testHandleOtherSchool_whitespaceOnlyName_doesNotClose() {
    sut.showOtherSchoolModal = true
    sut.otherSchoolName = "   "

    sut.handleOtherSchool()

    XCTAssertTrue(sut.showOtherSchoolModal)
  }

  // MARK: - Event Creation Tests

  func testCreateEvent_callsService_withCorrectData() async {
    sut.formData.type = .showcase
    sut.formData.name = "Spring Showcase 2026"
    sut.formData.startDate = date("2026-04-15")
    sut.formData.city = "Atlanta"
    sut.formData.state = "ga"

    _ = await sut.createEvent()

    XCTAssertEqual(mockService.createEventCallCount, 1)
    XCTAssertEqual(mockService.lastCreateEventRequest?.name, "Spring Showcase 2026")
    XCTAssertEqual(mockService.lastCreateEventRequest?.type, "showcase")
    XCTAssertEqual(mockService.lastCreateEventRequest?.startDate, "2026-04-15")
    XCTAssertEqual(mockService.lastCreateEventRequest?.state, "GA")
    XCTAssertEqual(mockService.lastCreateEventRequest?.userId, "test-user-id")
  }

  func testCreateEvent_onSuccess_returnsEventId() async {
    sut.formData.type = .camp
    sut.formData.name = "Summer Camp"
    sut.formData.startDate = date("2026-06-01")
    mockService.stubbedCreatedEvent = .mock(id: "new-event-123")

    let eventId = await sut.createEvent()

    XCTAssertEqual(eventId, "new-event-123")
    XCTAssertNil(sut.errorMessage)
  }

  func testCreateEvent_onFailure_setsError() async {
    sut.formData.type = .showcase
    sut.formData.name = "Test Event"
    sut.formData.startDate = date("2026-04-15")
    mockService.shouldThrowCreateEvent = true

    let eventId = await sut.createEvent()

    XCTAssertNil(eventId)
    XCTAssertNotNil(sut.errorMessage)
  }

  func testCreateEvent_preventsDuplicateSubmission() async {
    sut.formData.type = .showcase
    sut.formData.name = "Test Event"
    sut.formData.startDate = date("2026-04-15")
    sut.isSaving = true

    let eventId = await sut.createEvent()

    XCTAssertNil(eventId)
    XCTAssertEqual(mockService.createEventCallCount, 0)
  }

  func testCreateEvent_setsLoadingDuringSubmission() async {
    sut.formData.type = .showcase
    sut.formData.name = "Test"
    sut.formData.startDate = date("2026-04-15")

    _ = await sut.createEvent()

    XCTAssertFalse(sut.isSaving)
    XCTAssertEqual(mockService.createEventCallCount, 1)
  }

  func testCreateEvent_withInvalidForm_doesNotCallService() async {
    sut.formData.type = nil
    sut.formData.name = ""
    sut.formData.startDate = nil

    let eventId = await sut.createEvent()

    XCTAssertNil(eventId)
    XCTAssertEqual(mockService.createEventCallCount, 0)
  }

  func testCreateEvent_convertsCostToDouble() async {
    sut.formData.type = .showcase
    sut.formData.name = "Test Event"
    sut.formData.startDate = date("2026-04-15")
    sut.formData.cost = "150.50"

    _ = await sut.createEvent()

    XCTAssertEqual(mockService.lastCreateEventRequest?.cost, 150.50)
  }

  func testCreateEvent_emptyOptionalFields_sendsNil() async {
    sut.formData.type = .showcase
    sut.formData.name = "Minimal Event"
    sut.formData.startDate = date("2026-04-15")
    sut.formData.location = ""
    sut.formData.address = ""
    sut.formData.city = ""
    sut.formData.state = ""
    sut.formData.url = ""
    sut.formData.description = ""
    sut.formData.performanceNotes = ""

    _ = await sut.createEvent()

    let request = mockService.lastCreateEventRequest
    XCTAssertNil(request?.location)
    XCTAssertNil(request?.address)
    XCTAssertNil(request?.city)
    XCTAssertNil(request?.state)
    XCTAssertNil(request?.url)
    XCTAssertNil(request?.description)
    XCTAssertNil(request?.performanceNotes)
  }

  // MARK: - School Loading Tests

  func testLoadSchools_onSuccess_populatesSchools() async {
    mockService.stubbedSchools = [
      SchoolSummary(id: "s1", name: "Georgia Tech", location: "Atlanta, GA"),
      SchoolSummary(id: "s2", name: "UGA", location: "Athens, GA")
    ]

    await sut.loadSchools()

    XCTAssertEqual(sut.schools.count, 2)
    XCTAssertEqual(sut.schools.first?.name, "Georgia Tech")
    XCTAssertEqual(mockService.fetchSchoolsCallCount, 1)
    XCTAssertEqual(mockService.lastFetchSchoolsUserId, "test-user-id")
  }

  func testLoadSchools_onFailure_setsError() async {
    mockService.shouldThrowFetchSchools = true

    await sut.loadSchools()

    XCTAssertTrue(sut.schools.isEmpty)
    XCTAssertNotNil(sut.errorMessage)
  }

  // MARK: - Save New School Tests

  func testSaveNewSchool_withName_createsSchool() async {
    sut.newSchoolName = "Clemson University"
    sut.newSchoolLocation = "Clemson, SC"
    mockService.stubbedCreatedSchool = SchoolSummary(
      id: "new-school-99",
      name: "Clemson University",
      location: "Clemson, SC"
    )

    await sut.saveNewSchool()

    XCTAssertEqual(mockService.createSchoolCallCount, 1)
    XCTAssertEqual(mockService.lastCreateSchoolName, "Clemson University")
    XCTAssertEqual(mockService.lastCreateSchoolLocation, "Clemson, SC")
    XCTAssertEqual(mockService.lastCreateSchoolUserId, "test-user-id")
  }

  func testSaveNewSchool_success_addsSchoolToList() async {
    sut.newSchoolName = "Clemson"
    mockService.stubbedCreatedSchool = SchoolSummary(id: "new-1", name: "Clemson", location: nil)

    await sut.saveNewSchool()

    XCTAssertTrue(sut.schools.contains(where: { $0.id == "new-1" }))
  }

  func testSaveNewSchool_success_preselectsNewSchool() async {
    sut.newSchoolName = "Clemson"
    mockService.stubbedCreatedSchool = SchoolSummary(id: "new-school-99", name: "Clemson", location: nil)

    await sut.saveNewSchool()

    XCTAssertEqual(sut.formData.schoolId, "new-school-99")
    XCTAssertFalse(sut.showAddSchoolModal)
  }

  func testSaveNewSchool_failure_setsError() async {
    sut.newSchoolName = "Clemson"
    mockService.shouldThrowCreateSchool = true

    await sut.saveNewSchool()

    XCTAssertNotNil(sut.errorMessage)
  }

  func testSaveNewSchool_emptyName_doesNotCallService() async {
    sut.newSchoolName = ""

    await sut.saveNewSchool()

    XCTAssertEqual(mockService.createSchoolCallCount, 0)
  }

  func testSaveNewSchool_whitespaceOnlyName_doesNotCallService() async {
    sut.newSchoolName = "   "

    await sut.saveNewSchool()

    XCTAssertEqual(mockService.createSchoolCallCount, 0)
  }

  func testSaveNewSchool_setsIsSavingSchool_duringCall() async {
    sut.newSchoolName = "Clemson"
    mockService.stubbedCreatedSchool = SchoolSummary(id: "new-1", name: "Clemson", location: nil)

    await sut.saveNewSchool()

    XCTAssertFalse(sut.isSavingSchool)
    XCTAssertEqual(mockService.createSchoolCallCount, 1)
  }

  // MARK: - Initial State Tests

  func testInitialState_formDataIsEmpty() {
    XCTAssertNil(sut.formData.type)
    XCTAssertEqual(sut.formData.name, "")
    XCTAssertNil(sut.formData.startDate)
    XCTAssertFalse(sut.formData.registered)
    XCTAssertFalse(sut.formData.attended)
  }

  func testInitialState_isNotLoading() {
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
    XCTAssertTrue(sut.validationErrors.isEmpty)
  }

  func testInitialState_modalsAreClosed() {
    XCTAssertFalse(sut.showOtherSchoolModal)
    XCTAssertFalse(sut.showAddSchoolModal)
  }

  func testInitialState_isSavingSchool_isFalse() {
    XCTAssertFalse(sut.isSavingSchool)
  }
}
