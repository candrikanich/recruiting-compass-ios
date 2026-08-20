import XCTest
@testable import TheRecruitingCompass

@MainActor
final class CommunicationTemplatesViewModelTests: XCTestCase {
  nonisolated deinit {}
  var viewModel: CommunicationTemplatesViewModel!
  var mockService: MockCommunicationTemplatesService!

  override func setUp() async throws {
    mockService = MockCommunicationTemplatesService()
    viewModel = CommunicationTemplatesViewModel(service: mockService)
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
  }

  // MARK: - Initial State

  func testInitialState() {
    XCTAssertTrue(viewModel.templates.isEmpty)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertEqual(viewModel.activeTab, .list)
    XCTAssertNil(viewModel.filterType)
    XCTAssertNil(viewModel.editingTemplate)
    XCTAssertFalse(viewModel.formData.isValid)
    XCTAssertFalse(viewModel.showDeleteConfirmation)
    XCTAssertNil(viewModel.templateToDeleteId)
  }

  // MARK: - loadTemplates Tests

  func testLoadTemplates_Success_PopulatesTemplates() async {
    mockService.mockTemplates = makeTemplates(count: 3)

    await viewModel.loadTemplates()

    XCTAssertEqual(viewModel.templates.count, 3)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertEqual(mockService.fetchTemplatesCallCount, 1)
  }

  func testLoadTemplates_Error_SetsErrorMessage() async {
    mockService.shouldThrowOnFetch = true

    await viewModel.loadTemplates()

    XCTAssertTrue(viewModel.templates.isEmpty)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNotNil(viewModel.errorMessage)
  }

  func testLoadTemplates_Empty_SetsEmptyArray() async {
    mockService.mockTemplates = []

    await viewModel.loadTemplates()

    XCTAssertTrue(viewModel.templates.isEmpty)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
  }

  // MARK: - filteredTemplates Tests

  func testFilteredTemplates_NoFilter_ReturnsAll() async {
    mockService.mockTemplates = makeTemplates(count: 5)
    await viewModel.loadTemplates()
    viewModel.filterType = nil

    XCTAssertEqual(viewModel.filteredTemplates.count, 5)
  }

  func testFilteredTemplates_EmailFilter_ReturnsOnlyEmail() async {
    mockService.mockTemplates = [
      makeTemplate(id: "1", type: .email),
      makeTemplate(id: "2", type: .message),
      makeTemplate(id: "3", type: .email),
      makeTemplate(id: "4", type: .social)
    ]
    await viewModel.loadTemplates()

    viewModel.filterType = .email

    XCTAssertEqual(viewModel.filteredTemplates.count, 2)
    XCTAssertTrue(viewModel.filteredTemplates.allSatisfy { $0.type == .email })
  }

  func testFilteredTemplates_TextFilter_ReturnsOnlyText() async {
    mockService.mockTemplates = [
      makeTemplate(id: "1", type: .email),
      makeTemplate(id: "2", type: .message),
      makeTemplate(id: "3", type: .message)
    ]
    await viewModel.loadTemplates()

    viewModel.filterType = .message

    XCTAssertEqual(viewModel.filteredTemplates.count, 2)
    XCTAssertTrue(viewModel.filteredTemplates.allSatisfy { $0.type == .message })
  }

  func testFilteredTemplates_TwitterFilter_ReturnsOnlyTwitter() async {
    mockService.mockTemplates = [
      makeTemplate(id: "1", type: .social),
      makeTemplate(id: "2", type: .email),
      makeTemplate(id: "3", type: .social)
    ]
    await viewModel.loadTemplates()

    viewModel.filterType = .social

    XCTAssertEqual(viewModel.filteredTemplates.count, 2)
    XCTAssertTrue(viewModel.filteredTemplates.allSatisfy { $0.type == .social })
  }

  func testFilteredTemplates_FilterWithNoMatches_ReturnsEmpty() async {
    mockService.mockTemplates = [
      makeTemplate(id: "1", type: .email),
      makeTemplate(id: "2", type: .email)
    ]
    await viewModel.loadTemplates()

    viewModel.filterType = .social

    XCTAssertTrue(viewModel.filteredTemplates.isEmpty)
  }

  // MARK: - Cached filteredTemplates Staleness Tests
  // filteredTemplates is a cached stored property (Phase 3.3), recomputed via
  // didSet on templates/filterType/searchQuery — not read live.

  func testFilteredTemplates_UpdatesWhenReloadedWithoutTouchingFilter() async {
    mockService.mockTemplates = [
      makeTemplate(id: "1", type: .email),
      makeTemplate(id: "2", type: .message)
    ]
    await viewModel.loadTemplates()
    viewModel.filterType = .email
    XCTAssertEqual(viewModel.filteredTemplates.count, 1)

    mockService.mockTemplates = [
      makeTemplate(id: "3", type: .email),
      makeTemplate(id: "4", type: .email)
    ]
    await viewModel.loadTemplates()

    XCTAssertEqual(viewModel.filteredTemplates.count, 2)
  }

  func testFilteredTemplates_UpdatesAfterDeleteWithoutExplicitRecompute() async {
    let keep = makeTemplate(id: "keep", type: .email)
    let remove = makeTemplate(id: "remove", type: .email)
    mockService.mockTemplates = [keep, remove]
    await viewModel.loadTemplates()
    viewModel.filterType = .email
    XCTAssertEqual(viewModel.filteredTemplates.count, 2)

    viewModel.confirmDelete(id: "remove")
    await viewModel.executeDelete()

    XCTAssertEqual(viewModel.filteredTemplates.count, 1)
    XCTAssertEqual(viewModel.filteredTemplates.first?.id, "keep")
  }

  // MARK: - typeCounts Tests

  func testTypeCounts_CalculatesCorrectly() async {
    mockService.mockTemplates = [
      makeTemplate(id: "1", type: .email),
      makeTemplate(id: "2", type: .email),
      makeTemplate(id: "3", type: .message),
      makeTemplate(id: "4", type: .social)
    ]
    await viewModel.loadTemplates()

    let counts = viewModel.typeCounts
    XCTAssertEqual(counts[nil], 4)
    XCTAssertEqual(counts[.email], 2)
    XCTAssertEqual(counts[.message], 1)
    XCTAssertEqual(counts[.social], 1)
  }

  // MARK: - saveTemplate Tests

  func testSaveTemplate_Create_WhenValid_CallsCreateOnService() async {
    viewModel.formData.name = "New Template"
    viewModel.formData.type = .email
    viewModel.formData.body = "Hello {{coach_name}}"
    viewModel.editingTemplate = nil

    await viewModel.saveTemplate()

    XCTAssertEqual(mockService.createTemplateCallCount, 1)
    XCTAssertEqual(mockService.updateTemplateCallCount, 0)
    XCTAssertEqual(mockService.lastCreateFormData?.name, "New Template")
    XCTAssertEqual(viewModel.templates.count, 1)
    XCTAssertEqual(viewModel.activeTab, .list)
  }

  func testSaveTemplate_Update_WhenEditing_CallsUpdateOnService() async {
    let existing = makeTemplate(id: "edit-1", name: "Old Name")
    mockService.mockTemplates = [existing]
    await viewModel.loadTemplates()

    viewModel.startEditing(template: existing)
    viewModel.formData.name = "Updated Name"
    viewModel.formData.body = "Updated body content"

    await viewModel.saveTemplate()

    XCTAssertEqual(mockService.updateTemplateCallCount, 1)
    XCTAssertEqual(mockService.createTemplateCallCount, 0)
    XCTAssertEqual(mockService.lastUpdateId, "edit-1")
    XCTAssertEqual(viewModel.activeTab, .list)
    XCTAssertNil(viewModel.editingTemplate)
  }

  func testSaveTemplate_InvalidFormData_DoesNotCallService() async {
    viewModel.formData.name = ""
    viewModel.formData.body = ""

    await viewModel.saveTemplate()

    XCTAssertEqual(mockService.createTemplateCallCount, 0)
    XCTAssertEqual(mockService.updateTemplateCallCount, 0)
  }

  func testSaveTemplate_Create_Error_SetsErrorMessage() async {
    viewModel.formData.name = "Template"
    viewModel.formData.body = "Body text"
    mockService.shouldThrowOnCreate = true

    await viewModel.saveTemplate()

    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.templates.isEmpty)
  }

  func testSaveTemplate_Create_InsertsAtFront() async {
    let existing = makeTemplate(id: "old-1", name: "Old")
    mockService.mockTemplates = [existing]
    await viewModel.loadTemplates()

    viewModel.formData.name = "Newest"
    viewModel.formData.body = "New body"

    await viewModel.saveTemplate()

    XCTAssertEqual(viewModel.templates.count, 2)
    XCTAssertEqual(viewModel.templates[0].id, "new-template")
  }

  func testSaveTemplate_Update_ReplacesInPlace() async {
    let existing = makeTemplate(id: "edit-1", name: "Original")
    mockService.mockTemplates = [existing]
    await viewModel.loadTemplates()

    let updatedReturn = makeTemplate(id: "edit-1", name: "Updated")
    mockService.mockUpdatedTemplate = updatedReturn

    viewModel.startEditing(template: existing)
    viewModel.formData.name = "Updated"
    viewModel.formData.body = "Updated body"

    await viewModel.saveTemplate()

    XCTAssertEqual(viewModel.templates.count, 1)
    XCTAssertEqual(viewModel.templates[0].name, "Updated")
  }

  // MARK: - startEditing Tests

  func testStartEditing_PopulatesFormData() {
    let template = makeTemplate(
      id: "t-1",
      name: "Intro Email",
      type: .message,
      body: "Hi there"
    )

    viewModel.startEditing(template: template)

    XCTAssertEqual(viewModel.formData.name, "Intro Email")
    XCTAssertEqual(viewModel.formData.type, .message)
    XCTAssertEqual(viewModel.formData.body, "Hi there")
    XCTAssertEqual(viewModel.editingTemplate?.id, "t-1")
    XCTAssertEqual(viewModel.activeTab, .create)
  }

  func testStartEditing_PredefinedTemplate_EntersCopyMode() {
    let predefined = CommunicationTemplate(
      id: "pre-1", userId: "", name: "First Contact", type: .email,
      body: "Hello coach", variables: nil,
      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z",
      isPredefined: true
    )

    viewModel.startEditing(template: predefined)

    XCTAssertTrue(viewModel.isCustomizingPredefined)
    XCTAssertNil(viewModel.editingTemplate, "not edited in place — a new template will be created")
    XCTAssertEqual(viewModel.formData.name, "Copy of First Contact")
    XCTAssertEqual(viewModel.formData.body, "Hello coach")
    XCTAssertEqual(viewModel.activeTab, .create)
  }

  func testSaveTemplate_FromPredefinedCopy_CreatesInsteadOfUpdates() async {
    let predefined = CommunicationTemplate(
      id: "pre-1", userId: "", name: "First Contact", type: .email,
      body: "Hello coach", variables: nil,
      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z",
      isPredefined: true
    )
    viewModel.startEditing(template: predefined)

    await viewModel.saveTemplate()

    XCTAssertEqual(mockService.createTemplateCallCount, 1, "copy is created")
    XCTAssertEqual(mockService.updateTemplateCallCount, 0, "predefined row is never updated")
    XCTAssertFalse(viewModel.isCustomizingPredefined)
    XCTAssertEqual(viewModel.activeTab, .list)
  }

  func testStartEditing_OwnedTemplate_EditsInPlace() {
    let owned = makeTemplate(id: "own-1", name: "My Template")

    viewModel.startEditing(template: owned)

    XCTAssertFalse(viewModel.isCustomizingPredefined)
    XCTAssertEqual(viewModel.editingTemplate?.id, "own-1")
    XCTAssertEqual(viewModel.formData.name, "My Template")
  }

  // MARK: - cancelEdit Tests

  func testCancelEdit_ResetsFormAndSwitchesToList() {
    let template = makeTemplate(id: "t-1", name: "Editing")
    viewModel.startEditing(template: template)
    XCTAssertEqual(viewModel.activeTab, .create)
    XCTAssertNotNil(viewModel.editingTemplate)

    viewModel.cancelEdit()

    XCTAssertEqual(viewModel.formData.name, "")
    XCTAssertEqual(viewModel.formData.body, "")
    XCTAssertNil(viewModel.editingTemplate)
    XCTAssertEqual(viewModel.activeTab, .list)
  }

  // MARK: - confirmDelete / executeDelete Tests

  func testConfirmDelete_SetsDeleteState() {
    viewModel.confirmDelete(id: "del-1")

    XCTAssertEqual(viewModel.templateToDeleteId, "del-1")
    XCTAssertTrue(viewModel.showDeleteConfirmation)
  }

  func testExecuteDelete_Success_RemovesTemplate() async {
    mockService.mockTemplates = [
      makeTemplate(id: "1"),
      makeTemplate(id: "2"),
      makeTemplate(id: "3")
    ]
    await viewModel.loadTemplates()

    viewModel.confirmDelete(id: "2")
    await viewModel.executeDelete()

    XCTAssertEqual(mockService.deleteTemplateCallCount, 1)
    XCTAssertEqual(mockService.lastDeleteId, "2")
    XCTAssertEqual(viewModel.templates.count, 2)
    XCTAssertFalse(viewModel.templates.contains { $0.id == "2" })
    XCTAssertFalse(viewModel.showDeleteConfirmation)
    XCTAssertNil(viewModel.templateToDeleteId)
    XCTAssertEqual(viewModel.activeTab, .list)
  }

  func testExecuteDelete_Error_KeepsTemplate() async {
    mockService.mockTemplates = [makeTemplate(id: "1")]
    await viewModel.loadTemplates()
    mockService.shouldThrowOnDelete = true

    viewModel.confirmDelete(id: "1")
    await viewModel.executeDelete()

    XCTAssertEqual(viewModel.templates.count, 1)
    XCTAssertNotNil(viewModel.errorMessage)
  }

  func testExecuteDelete_NoTemplateToDeleteId_DoesNothing() async {
    viewModel.templateToDeleteId = nil

    await viewModel.executeDelete()

    XCTAssertEqual(mockService.deleteTemplateCallCount, 0)
  }

  // MARK: - selectFilter Tests

  func testSelectFilter_SetsFilterType() {
    viewModel.selectFilter(.email)
    XCTAssertEqual(viewModel.filterType, .email)

    viewModel.selectFilter(nil)
    XCTAssertNil(viewModel.filterType)
  }

  // MARK: - Helpers

  private func makeTemplates(count: Int) -> [CommunicationTemplate] {
    (0..<count).map { index in
      makeTemplate(id: "\(index)")
    }
  }

  private func makeTemplate(
    id: String = "template-1",
    name: String = "Test Template",
    type: TemplateType = .email,
    body: String = "Test body content for template"
  ) -> CommunicationTemplate {
    CommunicationTemplate(
      id: id,
      userId: "user-1",
      name: name,
      type: type,
      body: body,
      variables: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }
}
