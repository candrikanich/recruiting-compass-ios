import XCTest
@testable import TheRecruitingCompass

/// #389 (continued): events, documents, performance, offers and video links. With no loaded family each
/// refuses before the service is called; with one, it stamps the real id.
@MainActor
final class FamilyIdInsertGuardSecondaryTests: XCTestCase {
  nonisolated deinit {}

  private let copy = "Your family account is still loading. Please wait a moment and try again."

  private func familylessManager(auth: MockAuthManager) -> FamilyManager {
    FamilyManager(familyService: MockFamilyService(), authManager: auth)
  }

  private func tempFile(ext: String = "mp4") -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("guard-\(UUID().uuidString).\(ext)")
    try? Data(count: 1).write(to: url)
    return url
  }

  // MARK: - Events

  func testEventDetail_noFamily_doesNotLogInteractionOrMetric() async {
    let service = MockEventsService()
    let auth = MockAuthManager()
    let fixture = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
    let vm = EventDetailViewModel(
      eventsService: service, familyManager: fixture, authManager: auth, eventId: "e1"
    )
    service.stubbedFetchedEvent = .mock()
    await vm.loadAll()
    fixture.currentMember = nil
    fixture.familyUnit = nil

    vm.startQuickLog()
    vm.interactionData.type = .inPersonVisit
    await vm.logInteraction()
    let interactionError = vm.errorMessage
    vm.errorMessage = nil
    vm.startAddMetric()
    vm.newMetricData.valueText = "92.5"
    vm.newMetricData.metricType = .velocity
    await vm.addMetric()

    XCTAssertEqual(service.createInteractionCallCount, 0)
    XCTAssertEqual(service.createMetricCallCount, 0)
    XCTAssertEqual(interactionError, copy)
    XCTAssertEqual(vm.errorMessage, copy)
  }

  func testCreateEvent_noFamily_doesNotInsert() async {
    for family in ["", "  "] {
      let service = MockEventsService()
      let vm = CreateEventViewModel(eventsService: service, userId: "u1", familyUnitId: family)
      vm.formData.type = .showcase
      vm.formData.name = "Spring Showcase"
      vm.formData.startDate = Date()

      let id = await vm.createEvent()

      XCTAssertNil(id)
      XCTAssertEqual(service.createEventCallCount, 0)
      XCTAssertEqual(vm.errorMessage, CreateEventViewModel.familyNotLoadedMessage)
    }
  }

  func testEventsService_createSchool_requiresFamily() async {
    // The real service is the last line of defence for any caller that skipped the view-model guard.
    let service = EventsServiceImpl(supabaseManager: .shared)
    for family in [nil, "", "  "] as [String?] {
      do {
        _ = try await service.createSchool(name: "X", location: nil, userId: "u1", familyUnitId: family)
        XCTFail("createSchool must throw without a family id")
      } catch {
        XCTAssertEqual(error as? FamilyUnitID.MissingError, .missing)
      }
    }
  }

  // MARK: - Documents

  func testDocumentsList_noFamily_doesNotUpload() async {
    let docs = MockDocumentsService()
    let auth = MockAuthManager()
    auth.setMockUser(User(
      id: "user-1", email: "t@example.com", emailConfirmedAt: nil,
      createdAt: "", updatedAt: "", role: .player
    ))
    let vm = DocumentsListViewModel(
      documentsService: docs, schoolsService: MockSchoolsService(), authManager: auth,
      familyManager: familylessManager(auth: auth), cache: InMemoryCache()
    )
    let file = tempFile()
    defer { try? FileManager.default.removeItem(at: file) }
    vm.uploadType = .highlightVideo
    vm.uploadTitle = "Clip"
    vm.setSelectedFile(file)

    await vm.uploadDocument()

    XCTAssertEqual(docs.uploadDocumentCallCount, 0)
    XCTAssertEqual(vm.uploadError, copy)
  }

  func testDocumentDetail_noFamily_doesNotUploadNewVersion() async {
    let docs = MockDocumentsService()
    let auth = MockAuthManager()
    auth.setMockUser(User(
      id: "user-1", email: "t@example.com", emailConfirmedAt: nil,
      createdAt: "", updatedAt: "", role: .player
    ))
    let vm = DocumentDetailViewModel(
      documentId: "doc-1", documentsService: docs, schoolsService: MockSchoolsService(),
      authManager: auth, familyManager: familylessManager(auth: auth), cache: InMemoryCache()
    )
    docs.stubbedDocument = .mock(id: "doc-1", title: "Doc", type: .highlightVideo)
    await vm.loadDocument()
    let file = tempFile()
    defer { try? FileManager.default.removeItem(at: file) }

    await vm.uploadNewVersion(file: file)

    XCTAssertEqual(docs.uploadDocumentCallCount, 0)
    XCTAssertEqual(vm.errorMessage, copy)
  }

  // MARK: - Performance

  func testPerformanceDashboard_noFamily_doesNotCreateMetric() async {
    let service = MockPerformanceService()
    let auth = MockAuthManager()
    auth.setMockUser(User(
      id: "user-1", email: "t@example.com", emailConfirmedAt: nil,
      createdAt: "", updatedAt: "", role: .player
    ))
    let vm = PerformanceDashboardViewModel(
      performanceService: service, familyManager: familylessManager(auth: auth),
      authManager: auth, cache: InMemoryCache()
    )
    vm.addFormState.metricType = .velocity
    vm.addFormState.value = "92.5"

    await vm.addMetric()

    XCTAssertEqual(service.createMetricCallCount, 0)
    XCTAssertEqual(vm.errorMessage, copy)
  }

  // MARK: - Offers

  func testOffers_noFamily_doesNotCreateOffer() async {
    let service = MockOffersService()
    let auth = MockAuthManager()
    auth.setMockUser(User(
      id: "user-1", email: "t@example.com", emailConfirmedAt: nil,
      createdAt: "", updatedAt: "", role: .player
    ))
    let vm = OffersListViewModel(
      offersService: service, familyManager: familylessManager(auth: auth),
      authManager: auth, cache: InMemoryCache()
    )
    vm.formState.schoolId = "school-1"

    await vm.createOffer()

    XCTAssertEqual(service.createOfferCallCount, 0)
    XCTAssertEqual(vm.errorMessage, copy)
  }
}
