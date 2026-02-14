import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SchoolDetailViewModelPhase2Tests: XCTestCase {
  var viewModel: SchoolDetailViewModel!
  var mockSchoolsService: MockSchoolsService!
  var mockAuthManager: MockAuthManager!
  var mockFamilyManager: FamilyManager!

  override func setUp() async throws {
    mockSchoolsService = MockSchoolsService()
    mockAuthManager = MockAuthManager()
    mockFamilyManager = FamilyManager.shared

    // Set up authenticated user
    mockAuthManager.user = User(
      id: "user-1",
      email: "test@example.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      phone: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: nil
    )

    // Set up family unit
    mockFamilyManager.familyUnit = FamilyUnit(
      id: "family-1",
      playerUserId: "user-1",
      familyName: "Test Family",
      familyCode: nil,
      codeGeneratedAt: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z",
      homeLatitude: nil,
      homeLongitude: nil
    )

    viewModel = SchoolDetailViewModel(
      schoolId: "school-1",
      schoolsService: mockSchoolsService,
      authManager: mockAuthManager,
      familyManager: mockFamilyManager
    )
  }

  override func tearDown() async throws {
    viewModel = nil
    mockSchoolsService = nil
    mockAuthManager = nil
    mockFamilyManager.familyUnit = nil
  }

  // MARK: - Notes Tests

  func testStartEditingNotes_PopulatesField() {
    // Given
    let school = createMockSchool(notes: "Existing notes")
    viewModel.school = school

    // When
    viewModel.startEditingNotes()

    // Then
    XCTAssertTrue(viewModel.isEditingNotes)
    XCTAssertEqual(viewModel.editedNotes, "Existing notes")
  }

  func testStartEditingNotes_EmptyNotes() {
    // Given
    let school = createMockSchool(notes: "")
    viewModel.school = school

    // When
    viewModel.startEditingNotes()

    // Then
    XCTAssertTrue(viewModel.isEditingNotes)
    XCTAssertEqual(viewModel.editedNotes, "")
  }

  func testSaveNotes_Success() async {
    // Given
    let updatedSchool = createMockSchool(notes: "Updated notes")
    mockSchoolsService.stubbedSchool = updatedSchool
    viewModel.editedNotes = "Updated notes"
    viewModel.isEditingNotes = true

    // When
    await viewModel.saveNotes()

    // Then
    XCTAssertEqual(viewModel.school?.notes, "Updated notes")
    XCTAssertFalse(viewModel.isEditingNotes)
    XCTAssertFalse(viewModel.isSavingNotes)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testSaveNotes_EmptyString_NoOp() async {
    // Given
    viewModel.editedNotes = ""
    let callCountBefore = mockSchoolsService.updateNotesCallCount

    // When
    await viewModel.saveNotes()

    // Then
    XCTAssertEqual(mockSchoolsService.updateNotesCallCount, callCountBefore)
  }

  func testCancelEditingNotes_ClearsState() {
    // Given
    viewModel.isEditingNotes = true
    viewModel.editedNotes = "Some notes"

    // When
    viewModel.cancelEditingNotes()

    // Then
    XCTAssertFalse(viewModel.isEditingNotes)
    XCTAssertEqual(viewModel.editedNotes, "")
  }

  func testSaveNotes_Failure_ShowsError() async {
    // Given
    mockSchoolsService.shouldSucceed = false
    viewModel.editedNotes = "New notes"
    viewModel.isEditingNotes = true

    // When
    await viewModel.saveNotes()

    // Then
    XCTAssertTrue(viewModel.isEditingNotes) // Sheet stays open
    XCTAssertEqual(viewModel.errorMessage, "Failed to save notes")
    XCTAssertFalse(viewModel.isSavingNotes)
  }

  func testSaveNotes_LoadingState() async {
    // Given
    mockSchoolsService.stubbedSchool = createMockSchool()
    mockSchoolsService.delayDuration = 0.1
    viewModel.editedNotes = "New notes"

    // When
    let task = Task {
      await viewModel.saveNotes()
    }

    // Give async task time to start
    try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

    // Then
    XCTAssertTrue(viewModel.isSavingNotes)

    await task.value

    XCTAssertFalse(viewModel.isSavingNotes)
  }

  // MARK: - Private Notes Tests

  func testPrivateNoteForCurrentUser_ReturnsCorrectNote() {
    // Given
    let privateNotes: [String: String] = [
      "user-1": "My private note",
      "user-2": "Other user's note"
    ]
    let school = createMockSchool(privateNotes: privateNotes)
    viewModel.school = school

    // When
    let note = viewModel.privateNoteForCurrentUser

    // Then
    XCTAssertEqual(note, "My private note")
  }

  func testPrivateNoteForCurrentUser_NoNote_ReturnsEmpty() {
    // Given
    let school = createMockSchool(privateNotes: [:])
    viewModel.school = school

    // When
    let note = viewModel.privateNoteForCurrentUser

    // Then
    XCTAssertEqual(note, "")
  }

  func testStartEditingPrivateNotes_PopulatesField() {
    // Given
    let privateNotes: [String: String] = [
      "user-1": "My private note"
    ]
    let school = createMockSchool(privateNotes: privateNotes)
    viewModel.school = school

    // When
    viewModel.startEditingPrivateNotes()

    // Then
    XCTAssertTrue(viewModel.isEditingPrivateNotes)
    XCTAssertEqual(viewModel.editedPrivateNotes, "My private note")
  }

  func testSavePrivateNotes_Success() async {
    // Given
    let updatedSchool = createMockSchool()
    mockSchoolsService.stubbedSchool = updatedSchool
    viewModel.editedPrivateNotes = "Updated private note"
    viewModel.isEditingPrivateNotes = true

    // When
    await viewModel.savePrivateNotes()

    // Then
    XCTAssertFalse(viewModel.isEditingPrivateNotes)
    XCTAssertFalse(viewModel.isSavingPrivateNotes)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testSavePrivateNotes_ClearsNote_WhenEmpty() async {
    // Given
    mockSchoolsService.stubbedSchool = createMockSchool()
    viewModel.editedPrivateNotes = "" // Empty string should clear note
    viewModel.isEditingPrivateNotes = true

    // When
    await viewModel.savePrivateNotes()

    // Then
    XCTAssertFalse(viewModel.isEditingPrivateNotes)
    XCTAssertEqual(mockSchoolsService.lastPrivateNote, nil)
  }

  func testSavePrivateNotes_NoFamily_ShowsError() async {
    // Given
    mockFamilyManager.familyUnit = nil
    viewModel.editedPrivateNotes = "Note"

    // When
    await viewModel.savePrivateNotes()

    // Then
    XCTAssertEqual(viewModel.errorMessage, "No active family")
    XCTAssertFalse(viewModel.isSavingPrivateNotes)
  }

  func testCancelEditingPrivateNotes_ClearsState() {
    // Given
    viewModel.isEditingPrivateNotes = true
    viewModel.editedPrivateNotes = "Some private note"

    // When
    viewModel.cancelEditingPrivateNotes()

    // Then
    XCTAssertFalse(viewModel.isEditingPrivateNotes)
    XCTAssertEqual(viewModel.editedPrivateNotes, "")
  }

  // MARK: - Pros & Cons Tests

  func testAddPro_Success_ClearsInput() async {
    // Given
    let updatedSchool = createMockSchool(pros: ["Great facilities"])
    mockSchoolsService.stubbedSchool = updatedSchool
    viewModel.newPro = "Great facilities"

    // When
    await viewModel.addPro()

    // Then
    XCTAssertEqual(viewModel.school?.pros.count, 1)
    XCTAssertEqual(viewModel.newPro, "")
    XCTAssertFalse(viewModel.isAddingPro)
  }

  func testAddPro_EmptyString_NoOp() async {
    // Given
    viewModel.newPro = ""
    let callCountBefore = mockSchoolsService.addProCallCount

    // When
    await viewModel.addPro()

    // Then
    XCTAssertEqual(mockSchoolsService.addProCallCount, callCountBefore)
  }

  func testAddPro_WhitespaceOnly_NoOp() async {
    // Given
    viewModel.newPro = "   "
    let callCountBefore = mockSchoolsService.addProCallCount

    // When
    await viewModel.addPro()

    // Then
    XCTAssertEqual(mockSchoolsService.addProCallCount, callCountBefore)
  }

  func testAddPro_NoFamily_ShowsError() async {
    // Given
    mockFamilyManager.familyUnit = nil
    viewModel.newPro = "Great facilities"

    // When
    await viewModel.addPro()

    // Then
    XCTAssertEqual(viewModel.errorMessage, "No active family")
  }

  func testRemovePro_Success() async {
    // Given
    let updatedSchool = createMockSchool(pros: [])
    mockSchoolsService.stubbedSchool = updatedSchool

    // When
    await viewModel.removePro(at: 0)

    // Then
    XCTAssertEqual(mockSchoolsService.removeProCallCount, 1)
    XCTAssertEqual(mockSchoolsService.lastProIndex, 0)
  }

  func testRemovePro_NoFamily_ShowsError() async {
    // Given
    mockFamilyManager.familyUnit = nil

    // When
    await viewModel.removePro(at: 0)

    // Then
    XCTAssertEqual(viewModel.errorMessage, "No active family")
  }

  func testAddCon_Success_ClearsInput() async {
    // Given
    let updatedSchool = createMockSchool(cons: ["Far from home"])
    mockSchoolsService.stubbedSchool = updatedSchool
    viewModel.newCon = "Far from home"

    // When
    await viewModel.addCon()

    // Then
    XCTAssertEqual(viewModel.school?.cons.count, 1)
    XCTAssertEqual(viewModel.newCon, "")
    XCTAssertFalse(viewModel.isAddingCon)
  }

  func testAddCon_EmptyString_NoOp() async {
    // Given
    viewModel.newCon = ""
    let callCountBefore = mockSchoolsService.addConCallCount

    // When
    await viewModel.addCon()

    // Then
    XCTAssertEqual(mockSchoolsService.addConCallCount, callCountBefore)
  }

  func testAddCon_NoFamily_ShowsError() async {
    // Given
    mockFamilyManager.familyUnit = nil
    viewModel.newCon = "Far from home"

    // When
    await viewModel.addCon()

    // Then
    XCTAssertEqual(viewModel.errorMessage, "No active family")
  }

  func testRemoveCon_Success() async {
    // Given
    let updatedSchool = createMockSchool(cons: [])
    mockSchoolsService.stubbedSchool = updatedSchool

    // When
    await viewModel.removeCon(at: 0)

    // Then
    XCTAssertEqual(mockSchoolsService.removeConCallCount, 1)
    XCTAssertEqual(mockSchoolsService.lastConIndex, 0)
  }

  // MARK: - Basic Info Tests

  func testStartEditingBasicInfo_PopulatesForm() {
    // Given
    let school = createMockSchool(
      website: "test.edu",
      twitterHandle: "@testschool",
      instagramHandle: "@testschool"
    )
    viewModel.school = school

    // When
    viewModel.startEditingBasicInfo()

    // Then
    XCTAssertTrue(viewModel.isEditingBasicInfo)
    XCTAssertEqual(viewModel.editedBasicInfo.website, "test.edu")
    XCTAssertEqual(viewModel.editedBasicInfo.twitterHandle, "@testschool")
    XCTAssertEqual(viewModel.editedBasicInfo.instagramHandle, "@testschool")
  }

  func testStartEditingBasicInfo_NoSchool_NoOp() {
    // Given
    viewModel.school = nil

    // When
    viewModel.startEditingBasicInfo()

    // Then
    XCTAssertFalse(viewModel.isEditingBasicInfo)
  }

  func testCancelEditingBasicInfo_ClearsState() {
    // Given
    viewModel.isEditingBasicInfo = true
    viewModel.editedBasicInfo = EditableBasicInfo(
      website: "test.edu",
      twitterHandle: "@test",
      instagramHandle: "@test"
    )

    // When
    viewModel.cancelEditingBasicInfo()

    // Then
    XCTAssertFalse(viewModel.isEditingBasicInfo)
    XCTAssertTrue(viewModel.editedBasicInfo.website.isEmpty)
  }

  func testSaveBasicInfo_Success() async {
    // Given
    let updatedSchool = createMockSchool(
      website: "updated.edu",
      twitterHandle: "@updated",
      instagramHandle: "@updated"
    )
    mockSchoolsService.stubbedSchool = updatedSchool
    viewModel.editedBasicInfo = EditableBasicInfo(
      website: "updated.edu",
      twitterHandle: "@updated",
      instagramHandle: "@updated"
    )
    viewModel.isEditingBasicInfo = true

    // When
    await viewModel.saveBasicInfo()

    // Then
    XCTAssertEqual(viewModel.school?.website, "updated.edu")
    XCTAssertFalse(viewModel.isEditingBasicInfo)
    XCTAssertFalse(viewModel.isSavingBasicInfo)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testSaveBasicInfo_Failure_ShowsError() async {
    // Given
    mockSchoolsService.shouldSucceed = false
    viewModel.editedBasicInfo = EditableBasicInfo(website: "test.edu")
    viewModel.isEditingBasicInfo = true

    // When
    await viewModel.saveBasicInfo()

    // Then
    XCTAssertTrue(viewModel.isEditingBasicInfo) // Sheet stays open
    XCTAssertEqual(viewModel.errorMessage, "Failed to save information")
    XCTAssertFalse(viewModel.isSavingBasicInfo)
  }

  // MARK: - Computed Properties Tests

  func testCurrentUserId_ReturnsUserId() {
    // Given/When
    let userId = viewModel.currentUserId

    // Then
    XCTAssertEqual(userId, "user-1")
  }

  func testCurrentUserId_NoUser_ReturnsEmpty() {
    // Given
    mockAuthManager.user = nil
    let newViewModel = SchoolDetailViewModel(
      schoolId: "school-1",
      schoolsService: mockSchoolsService,
      authManager: mockAuthManager,
      familyManager: mockFamilyManager
    )

    // When
    let userId = newViewModel.currentUserId

    // Then
    XCTAssertEqual(userId, "")
  }

  func testIsEditingAnything_True_WhenEditingNotes() {
    // Given
    viewModel.isEditingNotes = true

    // When/Then
    XCTAssertTrue(viewModel.isEditingAnything)
  }

  func testIsEditingAnything_True_WhenEditingPrivateNotes() {
    // Given
    viewModel.isEditingPrivateNotes = true

    // When/Then
    XCTAssertTrue(viewModel.isEditingAnything)
  }

  func testIsEditingAnything_True_WhenEditingBasicInfo() {
    // Given
    viewModel.isEditingBasicInfo = true

    // When/Then
    XCTAssertTrue(viewModel.isEditingAnything)
  }

  func testIsEditingAnything_True_WhenEditingCoachingPhilosophy() {
    // Given
    viewModel.isEditingCoachingPhilosophy = true

    // When/Then
    XCTAssertTrue(viewModel.isEditingAnything)
  }

  func testIsEditingAnything_False_WhenNotEditing() {
    // Given/When/Then
    XCTAssertFalse(viewModel.isEditingAnything)
  }

  // MARK: - Helper Methods

  private func createMockSchool(
    notes: String? = nil,
    privateNotes: [String: String]? = nil,
    pros: [String] = [],
    cons: [String] = [],
    website: String? = nil,
    twitterHandle: String? = nil,
    instagramHandle: String? = nil
  ) -> School {
    School(
      id: "school-1",
      userId: "user-1",
      name: "Test University",
      location: "Test City, TS",
      city: "Test City",
      state: "TS",
      division: "D1",
      conference: "Test Conference",
      ranking: 10,
      isFavorite: false,
      website: website,
      faviconUrl: nil,
      twitterHandle: twitterHandle,
      instagramHandle: instagramHandle,
      ncaaId: nil,
      status: "interested",
      statusChangedAt: "2025-01-01T00:00:00Z",
      priorityTier: nil,
      notes: notes,
      privateNotes: privateNotes,
      pros: pros,
      cons: cons,
      offerDetails: nil,
      academicInfo: nil,
      amenities: nil,
      coachingPhilosophy: nil,
      coachingStyle: nil,
      recruitingApproach: nil,
      communicationStyle: nil,
      successMetrics: nil,
      fitScore: nil,
      fitTier: nil,
      familyUnitId: "family-1",
      createdBy: "user-1",
      updatedBy: "user-1",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
  }
}
