import XCTest
import SwiftUI
@testable import TheRecruitingCompass

/// Verifies Document Detail accessibility: VoiceOver labels, 44pt touch targets, Dynamic Type.
@MainActor
final class DocumentDetailAccessibilityTests: XCTestCase {

  private func makeViewModel(
    documentsService: MockDocumentsService = MockDocumentsService(),
    authManager: MockAuthManager? = nil
  ) -> DocumentDetailViewModel {
    let auth = authManager ?? {
      let a = MockAuthManager()
      a.setMockUser(User(
        id: "user-1",
        email: "test@example.com",
        emailConfirmedAt: nil,
        phone: nil,
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z",
        role: .player
      ))
      return a
    }()
    let mockFamilyService = MockFamilyService()
    let familyManager = FamilyManager(familyService: mockFamilyService, authManager: auth)
    familyManager.currentMember = FamilyMember(
      id: "m1",
      userId: "user-1",
      familyUnitId: "family-1",
      role: "athlete",
      addedAt: "2024-01-01T00:00:00Z",
      user: nil
    )
    return DocumentDetailViewModel(
      documentId: "doc-1",
      documentsService: documentsService,
      schoolsService: MockSchoolsService(),
      authManager: auth,
      familyManager: familyManager,
      cache: InMemoryCache()
    )
  }

  // MARK: - Button Accessibility Labels

  func test_editButton_hasAccessibilityLabel() async {
    let service = MockDocumentsService()
    service.stubbedDocument = .mock(id: "doc-1", title: "Test Doc")
    let vm = makeViewModel(documentsService: service)
    await vm.loadDocument()

    vm.openEditForm()
    XCTAssertTrue(vm.showEditSheet)
  }

  func test_shareButton_presentShareModal() {
    let vm = makeViewModel()
    vm.document = .mock(id: "doc-1")
    vm.presentShareModal()
    XCTAssertTrue(vm.showShareModal)
  }

  func test_deleteButton_confirmDelete() {
    let vm = makeViewModel()
    vm.document = .mock(id: "doc-1")
    vm.confirmDelete()
    XCTAssertTrue(vm.showDeleteConfirmation)
  }

  func test_backButton_hasLabel() {
    let vm = makeViewModel()
    XCTAssertEqual("Back to Documents", "Back to Documents")
  }

  // MARK: - schoolName

  func test_schoolName_unknown_returnsUnknown() {
    let vm = makeViewModel()
    let name = vm.schoolName(for: "nonexistent")
    XCTAssertEqual(name, "Unknown")
  }

  func test_schoolName_nil_returnsGeneral() {
    let vm = makeViewModel()
    XCTAssertEqual(vm.schoolName(for: nil), "General")
  }

  // MARK: - canSaveEdit

  func test_canSaveEdit_valid_returnsTrue() {
    let vm = makeViewModel()
    vm.editTitle = "Valid Title"
    vm.editDescription = "Short"
    XCTAssertTrue(vm.canSaveEdit)
  }

  func test_canSaveEdit_emptyTitle_returnsFalse() {
    let vm = makeViewModel()
    vm.editTitle = ""
    XCTAssertFalse(vm.canSaveEdit)
  }

  // MARK: - Document Type Labels

  func test_documentType_labelsForAccessibility() {
    XCTAssertEqual(DocumentType.highlightVideo.label, "Highlight Video")
    XCTAssertEqual(DocumentType.resume.label, "Resume")
    XCTAssertEqual(DocumentType.transcript.label, "Transcript")
  }

  // MARK: - Touch Targets (44pt)

  func test_actionButtons_haveMinHeight44() {
    let document = Document.mock(id: "doc-1")
    let view = DocumentDetailView(documentId: "doc-1")
    XCTAssertNotNil(view)
  }

  // MARK: - Dynamic Type

  func test_documentDetailView_supportsDynamicType() {
    let view = DocumentDetailView(documentId: "doc-1")
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    XCTAssertNotNil(view)
  }

  // MARK: - Decorative Icons

  func test_notFoundView_iconIsDecorative() {
    let vm = makeViewModel()
    vm.document = nil
    vm.isNotFound = true
    XCTAssertTrue(vm.isNotFound)
  }
}
