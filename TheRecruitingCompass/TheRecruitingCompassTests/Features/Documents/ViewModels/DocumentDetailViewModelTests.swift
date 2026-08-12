import XCTest
@testable import TheRecruitingCompass

@MainActor
final class DocumentDetailViewModelTests: XCTestCase {
  nonisolated deinit {}

  private var sut: DocumentDetailViewModel!
  private var mockDocuments: MockDocumentsService!
  private var mockSchools: MockSchoolsService!
  private var mockAuth: MockAuthManager!
  private var mockFamilyManager: FamilyManager!

  override func setUp() {
    super.setUp()
    mockDocuments = MockDocumentsService()
    mockSchools = MockSchoolsService()
    mockAuth = MockAuthManager()
    let mockFamilyService = MockFamilyService()
    mockFamilyManager = FamilyManager(familyService: mockFamilyService, authManager: mockAuth)
    mockFamilyManager.currentMember = FamilyMember(
      id: "member-1",
      userId: "user-1",
      familyUnitId: "family-1",
      role: "athlete",
      addedAt: "2024-01-01T00:00:00Z",
      user: nil
    )
    mockAuth.setMockUser(User(
      id: "user-1",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: .player
    ))
    sut = DocumentDetailViewModel(
      documentId: "doc-1",
      documentsService: mockDocuments,
      schoolsService: mockSchools,
      authManager: mockAuth,
      familyManager: mockFamilyManager,
      cache: InMemoryCache()
    )
  }

  override func tearDown() {
    sut = nil
    mockDocuments = nil
    mockSchools = nil
    mockAuth = nil
    mockFamilyManager = nil
    super.tearDown()
  }

  // MARK: - loadDocument

  func testLoadDocument_onSuccess_populatesDocumentAndVersions() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1", title: "Test Doc", type: .highlightVideo)
    mockDocuments.stubbedVersions = [
      DocumentVersion(id: "v1", version: 1, fileUrl: "https://example.com/v1.mp4", isCurrent: true, createdAt: "2026-02-17T00:00:00Z")
    ]

    await sut.loadDocument()

    XCTAssertEqual(sut.document?.id, "doc-1")
    XCTAssertEqual(sut.document?.title, "Test Doc")
    XCTAssertEqual(sut.versions.count, 1)
    XCTAssertNil(sut.errorMessage)
    XCTAssertFalse(sut.isLoading)
    XCTAssertFalse(sut.isNotFound)
  }

  func testLoadDocument_onFailure_setsError() async {
    mockDocuments.shouldThrowFetchDocument = true

    await sut.loadDocument()

    XCTAssertNil(sut.document)
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertTrue(sut.errorMessage!.contains("Unable to load document"))
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadDocument_notFound_setsIsNotFound() async {
    mockDocuments.shouldThrowFetchDocument = true
    mockDocuments.fetchDocumentErrorCode = 404

    await sut.loadDocument()

    XCTAssertNil(sut.document)
    XCTAssertTrue(sut.isNotFound)
    XCTAssertNil(sut.errorMessage)
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadDocument_noUser_setsErrorAndSkipsLoad() async {
    mockAuth.user = nil

    await sut.loadDocument()

    XCTAssertNil(sut.document)
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertTrue(sut.errorMessage!.contains("signed in"))
  }

  func testLoadDocument_callsFetchVersionsAfterDocumentLoaded() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1")
    mockDocuments.stubbedVersions = [DocumentVersion(id: "v1", version: 1, fileUrl: "u", isCurrent: true, createdAt: "2026-02-17T00:00:00Z")]

    await sut.loadDocument()

    XCTAssertEqual(sut.versions.count, 1)
  }

  // MARK: - saveEdit

  func testSaveEdit_onSuccess_updatesDocumentAndClosesSheet() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1", title: "Original")
    await sut.loadDocument()
    sut.openEditForm()
    sut.editTitle = "Updated Title"
    sut.editDescription = "New desc"
    mockDocuments.stubbedDocument = .mock(id: "doc-1", title: "Updated Title", description: "New desc")

    await sut.saveEdit()

    XCTAssertEqual(sut.document?.title, "Updated Title")
    XCTAssertFalse(sut.showEditSheet)
    XCTAssertFalse(sut.isSaving)
    XCTAssertNil(sut.errorMessage)
  }

  func testSaveEdit_onFailure_setsError() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1")
    await sut.loadDocument()
    sut.openEditForm()
    sut.editTitle = "Updated"
    mockDocuments.shouldThrowUpdateDocument = true

    await sut.saveEdit()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertTrue(sut.errorMessage!.contains("Failed to save"))
    XCTAssertFalse(sut.isSaving)
  }

  func testSaveEdit_whenCanSaveEditFalse_doesNotUpdateDocument() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1", title: "Original")
    await sut.loadDocument()
    sut.openEditForm()
    sut.editTitle = "   "

    await sut.saveEdit()

    XCTAssertEqual(sut.document?.title, "Original", "Document should be unchanged when canSaveEdit is false")
  }

  func testOpenEditForm_prefillsFromDocument() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1", title: "My Doc", description: "My desc", schoolId: "school-1")
    await sut.loadDocument()

    sut.openEditForm()

    XCTAssertTrue(sut.showEditSheet)
    XCTAssertEqual(sut.editTitle, "My Doc")
    XCTAssertEqual(sut.editDescription, "My desc")
    XCTAssertEqual(sut.editSchoolId, "school-1")
  }

  func testOpenEditForm_noDocument_doesNothing() {
    sut.openEditForm()
    XCTAssertFalse(sut.showEditSheet)
  }

  // MARK: - share

  func testPresentShareModal_showsShareModalAndResetsSelection() {
    sut.selectedSchoolIds = ["s1"]
    sut.presentShareModal()
    XCTAssertTrue(sut.showShareModal)
    XCTAssertTrue(sut.selectedSchoolIds.isEmpty)
  }

  func testToggleSchoolSelection_addsThenRemoves() {
    sut.toggleSchoolSelection("s1")
    XCTAssertTrue(sut.selectedSchoolIds.contains("s1"))
    sut.toggleSchoolSelection("s1")
    XCTAssertFalse(sut.selectedSchoolIds.contains("s1"))
  }

  func testSaveShare_onSuccess_closesModalAndRefreshesDocument() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1", sharedWithSchools: [])
    await sut.loadDocument()
    sut.presentShareModal()
    sut.toggleSchoolSelection("school-1")

    await sut.saveShare()

    XCTAssertFalse(sut.showShareModal)
    XCTAssertTrue(sut.selectedSchoolIds.isEmpty)
  }

  func testSaveShare_onFailure_setsError() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1")
    await sut.loadDocument()
    sut.presentShareModal()
    sut.toggleSchoolSelection("school-1")
    mockDocuments.shouldThrowShareDocument = true

    await sut.saveShare()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertTrue(sut.errorMessage!.contains("Failed to share"))
  }

  func testRemoveShare_onSuccess_refreshesDocument() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1", sharedWithSchools: ["s1"])
    await sut.loadDocument()

    await sut.removeShare(schoolId: "s1")

    XCTAssertNil(sut.errorMessage)
  }

  func testRemoveShare_onFailure_setsError() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1")
    await sut.loadDocument()
    mockDocuments.shouldThrowRevokeShare = true

    await sut.removeShare(schoolId: "s1")

    XCTAssertNotNil(sut.errorMessage)
  }

  // MARK: - delete

  func testConfirmDelete_showsConfirmation() {
    sut.confirmDelete()
    XCTAssertTrue(sut.showDeleteConfirmation)
  }

  func testDeleteDocument_onSuccess_setsShouldDismiss() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1")
    await sut.loadDocument()

    await sut.deleteDocument()

    XCTAssertTrue(sut.shouldDismiss)
    XCTAssertEqual(mockDocuments.lastDeleteDocumentId, "doc-1")
    XCTAssertEqual(mockDocuments.lastDeleteDocumentUserId, "user-1")
  }

  func testDeleteDocument_onFailure_setsError() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1")
    await sut.loadDocument()
    mockDocuments.shouldThrowDeleteDocument = true

    await sut.deleteDocument()

    XCTAssertFalse(sut.shouldDismiss)
    XCTAssertNotNil(sut.errorMessage)
  }

  func testDeleteDocument_noUser_doesNotCallService() async {
    mockAuth.user = nil
    mockDocuments.stubbedDocument = .mock(id: "doc-1")
    await sut.loadDocument()

    await sut.deleteDocument()

    XCTAssertEqual(mockDocuments.deleteDocumentCallCount, 0)
  }

  func testDeleteDocument_parentViewingAthlete_usesAthleteUserId() async {
    let familyManager = ParentViewingAthleteFixture.makeFamilyManager(authManager: mockAuth)
    sut = DocumentDetailViewModel(
      documentId: "doc-1",
      documentsService: mockDocuments,
      schoolsService: mockSchools,
      authManager: mockAuth,
      familyManager: familyManager,
      cache: InMemoryCache()
    )
    mockDocuments.stubbedDocument = .mock(id: "doc-1")
    await sut.loadDocument()

    await sut.deleteDocument()

    XCTAssertEqual(mockDocuments.lastDeleteDocumentUserId, ParentViewingAthleteFixture.athleteUserId)
  }

  // MARK: - restoreVersion

  func testConfirmRestore_setsVersionAndShowsConfirmation() {
    let version = DocumentVersion(id: "v1", version: 1, fileUrl: "u", isCurrent: false, createdAt: "2026-02-17T00:00:00Z")
    sut.confirmRestore(version: version)
    XCTAssertEqual(sut.versionToRestore?.id, "v1")
    XCTAssertTrue(sut.showRestoreConfirmation)
  }

  func testRestoreVersion_onSuccess_updatesDocumentAndVersions() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1")
    mockDocuments.stubbedVersions = [
      DocumentVersion(id: "current", version: 2, fileUrl: "u2", isCurrent: true, createdAt: "2026-02-18T00:00:00Z"),
      DocumentVersion(id: "v1", version: 1, fileUrl: "u1", isCurrent: false, createdAt: "2026-02-17T00:00:00Z")
    ]
    await sut.loadDocument()
    sut.confirmRestore(version: sut.versions[1])
    mockDocuments.stubbedDocument = .mock(id: "v1", title: "Test Document")

    await sut.restoreVersion()

    XCTAssertFalse(sut.showRestoreConfirmation)
    XCTAssertNil(sut.versionToRestore)
    XCTAssertNil(sut.errorMessage)
  }

  func testRestoreVersion_onFailure_setsError() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1")
    mockDocuments.stubbedVersions = [
      DocumentVersion(id: "current", version: 2, fileUrl: "u2", isCurrent: true, createdAt: "2026-02-18T00:00:00Z"),
      DocumentVersion(id: "v1", version: 1, fileUrl: "u1", isCurrent: false, createdAt: "2026-02-17T00:00:00Z")
    ]
    await sut.loadDocument()
    sut.confirmRestore(version: sut.versions[1])
    mockDocuments.shouldThrowUpdateDocumentIsCurrent = true

    await sut.restoreVersion()

    XCTAssertNotNil(sut.errorMessage)
  }

  func testRestoreVersion_noVersionToRestore_doesNothing() async {
    sut.versionToRestore = nil
    sut.document = .mock(id: "doc-1")
    await sut.restoreVersion()
    XCTAssertEqual(mockDocuments.updateDocumentIsCurrentCallCount, 0)
  }

  // MARK: - schoolName

  func testSchoolName_forKnownSchool_returnsName() async {
    mockSchools.stubbedSchools = [makeSchool(id: "s1", name: "Stanford")]
    await sut.loadSchools()

    let name = sut.schoolName(for: "s1")
    XCTAssertEqual(name, "Stanford")
  }

  func testSchoolName_forNil_returnsGeneral() {
    XCTAssertEqual(sut.schoolName(for: nil), "General")
  }

  // MARK: - canSaveEdit

  func testCanSaveEdit_validTitle_returnsTrue() {
    sut.editTitle = "Valid Title"
    sut.editDescription = "Short"
    XCTAssertTrue(sut.canSaveEdit)
  }

  func testCanSaveEdit_emptyTitle_returnsFalse() {
    sut.editTitle = "   "
    XCTAssertFalse(sut.canSaveEdit)
  }

  func testCanSaveEdit_descriptionTooLong_returnsFalse() {
    sut.editTitle = "Title"
    sut.editDescription = String(repeating: "x", count: 501)
    XCTAssertFalse(sut.canSaveEdit)
  }

  // MARK: - clearError

  func testClearError_clearsError() {
    sut.errorMessage = "Some error"
    sut.clearError()
    XCTAssertNil(sut.errorMessage)
  }

  // MARK: - Helpers

  private func makeSchool(id: String, name: String) -> School {
    School(
      id: id,
      userId: "user-1",
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
      status: "active",
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
      familyUnitId: "family-1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z"
    )
  }
}
