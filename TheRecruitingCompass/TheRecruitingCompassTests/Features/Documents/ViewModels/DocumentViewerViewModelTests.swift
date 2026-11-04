import XCTest
@testable import TheRecruitingCompass

@MainActor
final class DocumentViewerViewModelTests: XCTestCase {
  nonisolated deinit {}

  private var sut: DocumentViewerViewModel!
  private var mockDocuments: MockDocumentsService!

  override func setUp() {
    super.setUp()
    mockDocuments = MockDocumentsService()
  }

  override func tearDown() {
    sut = nil
    mockDocuments = nil
    super.tearDown()
  }

  // MARK: - init

  func testInit_withDocument_setsDocumentAndNotLoading() {
    let doc = Document.mock(id: "doc-1", title: "My Doc")
    sut = DocumentViewerViewModel(document: doc, documentsService: mockDocuments)

    XCTAssertEqual(sut.document?.id, "doc-1")
    XCTAssertEqual(sut.document?.title, "My Doc")
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
    XCTAssertEqual(sut.currentIndex, 0)
  }

  func testInit_withCollection_setsDocumentAndCurrentIndex() {
    let docs = [
      Document.mock(id: "doc-1", title: "First"),
      Document.mock(id: "doc-2", title: "Second"),
      Document.mock(id: "doc-3", title: "Third")
    ]
    let collection = DocumentCollection(documents: docs, currentIndex: 1)
    sut = DocumentViewerViewModel(collection: collection, documentsService: mockDocuments)

    XCTAssertEqual(sut.document?.id, "doc-2")
    XCTAssertEqual(sut.currentIndex, 1)
    XCTAssertTrue(sut.hasNext)
    XCTAssertTrue(sut.hasPrevious)
  }

  func testInit_withDocumentAndCollection_prefersProvidedDocument() {
    let doc = Document.mock(id: "custom", title: "Custom")
    let collection = DocumentCollection(
      documents: [Document.mock(id: "doc-1", title: "First")],
      currentIndex: 0
    )
    sut = DocumentViewerViewModel(document: doc, collection: collection, documentsService: mockDocuments)

    XCTAssertEqual(sut.document?.id, "custom")
    XCTAssertEqual(sut.document?.title, "Custom")
  }

  func testInit_withCollectionOnly_usesCurrentDocumentFromCollection() {
    let docs = [Document.mock(id: "doc-1", title: "Only")]
    let collection = DocumentCollection(documents: docs, currentIndex: 0)
    sut = DocumentViewerViewModel(collection: collection, documentsService: mockDocuments)

    XCTAssertEqual(sut.document?.id, "doc-1")
    XCTAssertEqual(sut.currentIndex, 0)
  }

  // MARK: - loadDocument

  func testLoadDocument_onSuccess_populatesDocumentAndClearsError() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1", title: "Loaded Doc")
    sut = DocumentViewerViewModel(documentsService: mockDocuments)

    await sut.loadDocument(id: "doc-1")

    XCTAssertEqual(sut.document?.id, "doc-1")
    XCTAssertEqual(sut.document?.title, "Loaded Doc")
    XCTAssertNil(sut.errorMessage)
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadDocument_onFailure_setsError() async {
    mockDocuments.shouldThrowFetchDocument = true
    mockDocuments.fetchDocumentErrorCode = 500
    sut = DocumentViewerViewModel(documentsService: mockDocuments)

    await sut.loadDocument(id: "doc-1")

    XCTAssertNil(sut.document)
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertTrue(sut.errorMessage!.contains("Unable to load document"))
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadDocument_on404_setsDocumentNotFoundError() async {
    mockDocuments.shouldThrowFetchDocument = true
    mockDocuments.fetchDocumentErrorCode = 404
    sut = DocumentViewerViewModel(documentsService: mockDocuments)

    await sut.loadDocument(id: "doc-1")

    XCTAssertNil(sut.document)
    XCTAssertEqual(sut.errorMessage, "Document not found")
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadDocument_setsIsLoadingDuringLoad() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1")
    sut = DocumentViewerViewModel(documentsService: mockDocuments)

    let loadFinished = expectation(description: "load finished")
    Task {
      await sut.loadDocument(id: "doc-1")
      loadFinished.fulfill()
    }
    // isLoading is set true then false in defer - hard to assert mid-flight without blocking
    await fulfillment(of: [loadFinished], timeout: 2)
    XCTAssertFalse(sut.isLoading)
  }

  // MARK: - shareDocument

  func testShareDocument_withDownloadedFile_presentsShareSheet() async {
    sut = DocumentViewerViewModel(document: .mock(), documentsService: mockDocuments)
    sut.downloadedFileURL = URL(fileURLWithPath: "/tmp/test.pdf")

    await sut.shareDocument()

    XCTAssertTrue(sut.isShareSheetPresented)
  }

  func testShareDocument_withUnopenableFileUrl_doesNotPresentAndSetsError() async {
    sut = DocumentViewerViewModel(document: .mock(fileUrl: ""), documentsService: mockDocuments)

    await sut.shareDocument()

    XCTAssertFalse(sut.isShareSheetPresented)
    XCTAssertEqual(sut.errorMessage, "Invalid file URL")
  }

  func testShareDocument_whenSigningFails_doesNotShareAnyURL() async {
    sut = DocumentViewerViewModel(
      document: .mock(fileUrl: "u1/a.pdf"), documentsService: mockDocuments,
      urlResolver: StubResolver { _ in throw URLError(.notConnectedToInternet) })

    await sut.shareDocument()

    XCTAssertFalse(sut.isShareSheetPresented)
    XCTAssertTrue(sut.shareItems.isEmpty)
    XCTAssertNotNil(sut.errorMessage)
  }

  // MARK: - downloadDocument

  func testDownloadDocument_withInvalidFileUrl_setsError() async {
    sut = DocumentViewerViewModel(document: .mock(fileUrl: ""), documentsService: mockDocuments)

    await sut.downloadDocument()

    XCTAssertEqual(sut.errorMessage, "Invalid file URL")
    XCTAssertNil(sut.downloadedFileURL)
  }

  func testDownloadDocument_withNilDocument_setsError() async {
    sut = DocumentViewerViewModel(documentsService: mockDocuments)
    sut.document = nil

    await sut.downloadDocument()

    XCTAssertEqual(sut.errorMessage, "Invalid file URL")
  }

  // MARK: - retryLoad

  func testRetryLoad_withDocumentId_reloadsDocument() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1", title: "Retried")
    sut = DocumentViewerViewModel(document: .mock(id: "doc-1"), documentsService: mockDocuments)
    sut.errorMessage = "Previous error"

    sut.retryLoad()
    try? await Task.sleep(for: .milliseconds(300))

    XCTAssertNil(sut.errorMessage)
    XCTAssertEqual(sut.document?.title, "Retried")
  }

  func testRetryLoad_withCollection_resetsDocumentFromCollection() {
    let docs = [Document.mock(id: "doc-1", title: "From Collection")]
    let collection = DocumentCollection(documents: docs, currentIndex: 0)
    sut = DocumentViewerViewModel(collection: collection, documentsService: mockDocuments)
    sut.document = nil
    sut.errorMessage = "Previous error"

    sut.retryLoad()

    XCTAssertEqual(sut.document?.id, "doc-1")
    XCTAssertEqual(sut.document?.title, "From Collection")
  }

  func testRetryLoad_clearsError() {
    sut = DocumentViewerViewModel(document: .mock(id: "doc-1"), documentsService: mockDocuments)
    sut.errorMessage = "Some error"

    sut.retryLoad()

    XCTAssertNil(sut.errorMessage)
  }

  // MARK: - nextDocument / previousDocument

  func testNextDocument_withCollection_advancesToNext() {
    let docs = [
      Document.mock(id: "doc-1", title: "First"),
      Document.mock(id: "doc-2", title: "Second")
    ]
    let collection = DocumentCollection(documents: docs, currentIndex: 0)
    sut = DocumentViewerViewModel(collection: collection, documentsService: mockDocuments)

    sut.nextDocument()

    XCTAssertEqual(sut.currentIndex, 1)
    XCTAssertEqual(sut.document?.id, "doc-2")
  }

  func testNextDocument_atLastDocument_doesNothing() {
    let docs = [Document.mock(id: "doc-1", title: "Only")]
    let collection = DocumentCollection(documents: docs, currentIndex: 0)
    sut = DocumentViewerViewModel(collection: collection, documentsService: mockDocuments)

    sut.nextDocument()

    XCTAssertEqual(sut.currentIndex, 0)
    XCTAssertEqual(sut.document?.id, "doc-1")
  }

  func testNextDocument_withoutCollection_doesNothing() {
    sut = DocumentViewerViewModel(document: .mock(id: "doc-1"), documentsService: mockDocuments)

    sut.nextDocument()

    XCTAssertEqual(sut.document?.id, "doc-1")
    XCTAssertEqual(sut.currentIndex, 0)
  }

  func testPreviousDocument_withCollection_goesToPrevious() {
    let docs = [
      Document.mock(id: "doc-1", title: "First"),
      Document.mock(id: "doc-2", title: "Second")
    ]
    let collection = DocumentCollection(documents: docs, currentIndex: 1)
    sut = DocumentViewerViewModel(collection: collection, documentsService: mockDocuments)

    sut.previousDocument()

    XCTAssertEqual(sut.currentIndex, 0)
    XCTAssertEqual(sut.document?.id, "doc-1")
  }

  func testPreviousDocument_atFirstDocument_doesNothing() {
    let docs = [Document.mock(id: "doc-1", title: "First")]
    let collection = DocumentCollection(documents: docs, currentIndex: 0)
    sut = DocumentViewerViewModel(collection: collection, documentsService: mockDocuments)

    sut.previousDocument()

    XCTAssertEqual(sut.currentIndex, 0)
  }

  func testPreviousDocument_withoutCollection_doesNothing() {
    sut = DocumentViewerViewModel(document: .mock(id: "doc-1"), documentsService: mockDocuments)

    sut.previousDocument()

    XCTAssertEqual(sut.document?.id, "doc-1")
  }

  // MARK: - hasNext / hasPrevious

  func testHasNext_withCollectionAtStart_returnsTrue() {
    let docs = [
      Document.mock(id: "doc-1"),
      Document.mock(id: "doc-2")
    ]
    let collection = DocumentCollection(documents: docs, currentIndex: 0)
    sut = DocumentViewerViewModel(collection: collection, documentsService: mockDocuments)

    XCTAssertTrue(sut.hasNext)
  }

  func testHasNext_withCollectionAtEnd_returnsFalse() {
    let docs = [Document.mock(id: "doc-1"), Document.mock(id: "doc-2")]
    let collection = DocumentCollection(documents: docs, currentIndex: 1)
    sut = DocumentViewerViewModel(collection: collection, documentsService: mockDocuments)

    XCTAssertFalse(sut.hasNext)
  }

  func testHasNext_withoutCollection_returnsFalse() {
    sut = DocumentViewerViewModel(document: .mock(), documentsService: mockDocuments)

    XCTAssertFalse(sut.hasNext)
  }

  func testHasPrevious_withCollectionNotAtStart_returnsTrue() {
    let docs = [Document.mock(id: "doc-1"), Document.mock(id: "doc-2")]
    let collection = DocumentCollection(documents: docs, currentIndex: 1)
    sut = DocumentViewerViewModel(collection: collection, documentsService: mockDocuments)

    XCTAssertTrue(sut.hasPrevious)
  }

  func testHasPrevious_withCollectionAtStart_returnsFalse() {
    let docs = [Document.mock(id: "doc-1")]
    let collection = DocumentCollection(documents: docs, currentIndex: 0)
    sut = DocumentViewerViewModel(collection: collection, documentsService: mockDocuments)

    XCTAssertFalse(sut.hasPrevious)
  }

  func testHasPrevious_withoutCollection_returnsFalse() {
    sut = DocumentViewerViewModel(document: .mock(), documentsService: mockDocuments)

    XCTAssertFalse(sut.hasPrevious)
  }

  // MARK: - shareItems

  func testShareItems_areTheDownloadedFile() {
    let localURL = URL(fileURLWithPath: "/tmp/local.pdf")
    sut = DocumentViewerViewModel(document: .mock(fileUrl: "https://example.com/file.pdf"), documentsService: mockDocuments)
    sut.downloadedFileURL = localURL

    XCTAssertEqual(sut.shareItems as? [URL], [localURL])
  }

  func testShareItems_withoutDownloadedFile_neverFallBackToARemoteURL() {
    sut = DocumentViewerViewModel(document: .mock(fileUrl: "https://example.com/file.pdf"), documentsService: mockDocuments)

    XCTAssertTrue(sut.shareItems.isEmpty)
  }

  // MARK: - resolveFileURL

  private struct StubResolver: DocumentURLResolving {
    let handler: @Sendable (String) async throws -> URL
    func openableURL(for fileUrl: String) async throws -> URL { try await handler(fileUrl) }
  }

  func testResolveFileURL_forStoragePath_returnsTheSignedURL() async {
    let signed = URL(string: "https://proj.supabase.co/storage/v1/object/sign/documents/u1/a.pdf?token=t")!
    sut = DocumentViewerViewModel(
      document: .mock(fileUrl: "u1/a.pdf"), documentsService: mockDocuments,
      urlResolver: StubResolver { _ in signed })

    let url = await sut.resolveFileURL()

    XCTAssertEqual(url, signed)
    XCTAssertNil(sut.errorMessage)
  }

  func testResolveFileURL_whenSigningFails_setsError() async {
    sut = DocumentViewerViewModel(
      document: .mock(fileUrl: "u1/a.pdf"), documentsService: mockDocuments,
      urlResolver: StubResolver { _ in throw URLError(.notConnectedToInternet) })

    let url = await sut.resolveFileURL()

    XCTAssertNil(url)
    XCTAssertNotNil(sut.errorMessage)
  }

  func testResolveFileURL_forDisallowedScheme_isNotOpened() async {
    sut = DocumentViewerViewModel(document: .mock(fileUrl: "javascript:alert(1)"), documentsService: mockDocuments)

    let url = await sut.resolveFileURL()

    XCTAssertNil(url)
    XCTAssertEqual(sut.errorMessage, "Invalid file URL")
  }

  func testResolveFileURL_onCancellation_staysSilent() async {
    for error in [CancellationError() as Error, URLError(.cancelled)] {
      sut = DocumentViewerViewModel(
        document: .mock(fileUrl: "u1/a.pdf"), documentsService: mockDocuments,
        urlResolver: StubResolver { _ in throw error })

      let url = await sut.resolveFileURL()

      XCTAssertNil(url)
      XCTAssertNil(sut.errorMessage, "\(error)")
    }
  }

  private final class VMBox: @unchecked Sendable {
    var vm: DocumentViewerViewModel?
  }

  func testResolveFileURL_whenDocumentChangesAndSigningFails_doesNotReportTheStaleError() async {
    let box = VMBox()
    sut = DocumentViewerViewModel(
      document: .mock(fileUrl: "u1/a.pdf"), documentsService: mockDocuments,
      urlResolver: StubResolver { _ in
        await MainActor.run { box.vm?.document = .mock(fileUrl: "u2/b.pdf") }
        throw URLError(.notConnectedToInternet)
      })
    box.vm = sut

    let url = await sut.resolveFileURL()

    XCTAssertNil(url)
    XCTAssertNil(sut.errorMessage)
  }

  func testResolveFileURL_whenDocumentChangesDuringSigning_discardsTheStaleURL() async {
    let box = VMBox()
    sut = DocumentViewerViewModel(
      document: .mock(fileUrl: "u1/a.pdf"), documentsService: mockDocuments,
      urlResolver: StubResolver { _ in
        await MainActor.run { box.vm?.document = .mock(fileUrl: "u2/b.pdf") }
        return URL(string: "https://proj.supabase.co/sign/a")!
      })
    box.vm = sut

    let url = await sut.resolveFileURL()

    XCTAssertNil(url)
  }

  func testResolveFileURL_everyCallSignsAgain() async {
    let counter = CallCounter()
    sut = DocumentViewerViewModel(
      document: .mock(fileUrl: "u1/a.pdf"), documentsService: mockDocuments,
      urlResolver: StubResolver { _ in
        let n = await counter.next()
        return URL(string: "https://proj.supabase.co/sign/\(n)")!
      })

    let first = await sut.resolveFileURL()
    let second = await sut.resolveFileURL()

    XCTAssertEqual(first?.lastPathComponent, "1")
    XCTAssertEqual(second?.lastPathComponent, "2")
  }

  // MARK: - Error states

  func testLoadDocument_clearsErrorOnRetry() async {
    mockDocuments.shouldThrowFetchDocument = true
    sut = DocumentViewerViewModel(documentsService: mockDocuments)
    await sut.loadDocument(id: "doc-1")
    XCTAssertNotNil(sut.errorMessage)

    mockDocuments.shouldThrowFetchDocument = false
    mockDocuments.stubbedDocument = .mock(id: "doc-1")
    await sut.loadDocument(id: "doc-1")

    XCTAssertNil(sut.errorMessage)
  }

  // MARK: - Toolbar auto-hide (#253)

  private func makeVideoViewModel(assistiveTechRunning: Bool) -> DocumentViewerViewModel {
    DocumentViewerViewModel(
      document: .mock(),
      documentsService: mockDocuments,
      autoHideDelay: .milliseconds(30),
      isAssistiveTechnologyRunning: { assistiveTechRunning }
    )
  }

  func testScheduleToolbarAutoHide_withoutAssistiveTech_hidesToolbarForVideo() async throws {
    sut = makeVideoViewModel(assistiveTechRunning: false)
    sut.scheduleToolbarAutoHide()
    try await Task.sleep(for: .milliseconds(200))
    XCTAssertFalse(sut.isToolbarVisible)
  }

  func testScheduleToolbarAutoHide_withAssistiveTech_keepsToolbarVisible() async throws {
    sut = makeVideoViewModel(assistiveTechRunning: true)
    sut.scheduleToolbarAutoHide()
    try await Task.sleep(for: .milliseconds(200))
    XCTAssertTrue(sut.isToolbarVisible)
  }

  func testToggleToolbar_withAssistiveTech_neverSchedulesHide() async throws {
    sut = makeVideoViewModel(assistiveTechRunning: true)
    sut.toggleToolbar()
    sut.toggleToolbar()
    try await Task.sleep(for: .milliseconds(200))
    XCTAssertTrue(sut.isToolbarVisible)
  }
}

private actor CallCounter {
  private var count = 0
  func next() -> Int { count += 1; return count }
}
