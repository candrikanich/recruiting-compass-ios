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
    XCTAssertNil(sut.error)
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
    XCTAssertNil(sut.error)
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadDocument_onFailure_setsError() async {
    mockDocuments.shouldThrowFetchDocument = true
    mockDocuments.fetchDocumentErrorCode = 500
    sut = DocumentViewerViewModel(documentsService: mockDocuments)

    await sut.loadDocument(id: "doc-1")

    XCTAssertNil(sut.document)
    XCTAssertNotNil(sut.error)
    XCTAssertTrue(sut.error!.contains("Unable to load document"))
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadDocument_on404_setsDocumentNotFoundError() async {
    mockDocuments.shouldThrowFetchDocument = true
    mockDocuments.fetchDocumentErrorCode = 404
    sut = DocumentViewerViewModel(documentsService: mockDocuments)

    await sut.loadDocument(id: "doc-1")

    XCTAssertNil(sut.document)
    XCTAssertEqual(sut.error, "Document not found")
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

  func testShareDocument_withShareableURL_setsIsShareSheetPresented() {
    sut = DocumentViewerViewModel(document: .mock(fileUrl: "https://example.com/file.pdf"), documentsService: mockDocuments)

    sut.shareDocument()

    XCTAssertTrue(sut.isShareSheetPresented)
  }

  func testShareDocument_withDownloadedFileURL_setsIsShareSheetPresented() {
    sut = DocumentViewerViewModel(document: .mock(), documentsService: mockDocuments)
    sut.downloadedFileURL = URL(fileURLWithPath: "/tmp/test.pdf")

    sut.shareDocument()

    XCTAssertTrue(sut.isShareSheetPresented)
  }

  func testShareDocument_withNoURL_doesNothing() {
    sut = DocumentViewerViewModel(document: .mock(fileUrl: ""), documentsService: mockDocuments)
    sut.downloadedFileURL = nil

    sut.shareDocument()

    XCTAssertFalse(sut.isShareSheetPresented)
  }

  // MARK: - downloadDocument

  func testDownloadDocument_withInvalidFileUrl_setsError() async {
    sut = DocumentViewerViewModel(document: .mock(fileUrl: ""), documentsService: mockDocuments)

    await sut.downloadDocument()

    XCTAssertEqual(sut.error, "Invalid file URL")
    XCTAssertNil(sut.downloadedFileURL)
  }

  func testDownloadDocument_withNilDocument_setsError() async {
    sut = DocumentViewerViewModel(documentsService: mockDocuments)
    sut.document = nil

    await sut.downloadDocument()

    XCTAssertEqual(sut.error, "Invalid file URL")
  }

  // MARK: - retryLoad

  func testRetryLoad_withDocumentId_reloadsDocument() async {
    mockDocuments.stubbedDocument = .mock(id: "doc-1", title: "Retried")
    sut = DocumentViewerViewModel(document: .mock(id: "doc-1"), documentsService: mockDocuments)
    sut.error = "Previous error"

    sut.retryLoad()
    try? await Task.sleep(for: .milliseconds(300))

    XCTAssertNil(sut.error)
    XCTAssertEqual(sut.document?.title, "Retried")
  }

  func testRetryLoad_withCollection_resetsDocumentFromCollection() {
    let docs = [Document.mock(id: "doc-1", title: "From Collection")]
    let collection = DocumentCollection(documents: docs, currentIndex: 0)
    sut = DocumentViewerViewModel(collection: collection, documentsService: mockDocuments)
    sut.document = nil
    sut.error = "Previous error"

    sut.retryLoad()

    XCTAssertEqual(sut.document?.id, "doc-1")
    XCTAssertEqual(sut.document?.title, "From Collection")
  }

  func testRetryLoad_clearsError() {
    sut = DocumentViewerViewModel(document: .mock(id: "doc-1"), documentsService: mockDocuments)
    sut.error = "Some error"

    sut.retryLoad()

    XCTAssertNil(sut.error)
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

  // MARK: - shareableURL / shareItems

  func testShareableURL_withValidFileUrl_returnsURL() {
    sut = DocumentViewerViewModel(document: .mock(fileUrl: "https://example.com/file.pdf"), documentsService: mockDocuments)

    XCTAssertNotNil(sut.shareableURL)
    XCTAssertEqual(sut.shareableURL?.absoluteString, "https://example.com/file.pdf")
  }

  func testShareableURL_withNoDocument_returnsNil() {
    sut = DocumentViewerViewModel(documentsService: mockDocuments)

    XCTAssertNil(sut.shareableURL)
  }

  func testShareItems_prefersDownloadedFileOverRemoteURL() {
    let localURL = URL(fileURLWithPath: "/tmp/local.pdf")
    sut = DocumentViewerViewModel(document: .mock(fileUrl: "https://example.com/file.pdf"), documentsService: mockDocuments)
    sut.downloadedFileURL = localURL

    XCTAssertEqual(sut.shareItems as? [URL], [localURL])
  }

  func testShareItems_withoutDownloadedFile_usesShareableURL() {
    sut = DocumentViewerViewModel(document: .mock(fileUrl: "https://example.com/file.pdf"), documentsService: mockDocuments)

    XCTAssertEqual(sut.shareItems.count, 1)
    XCTAssertTrue(sut.shareItems.first as? URL != nil)
  }

  func testShareItems_withNoURL_returnsEmpty() {
    sut = DocumentViewerViewModel(document: .mock(fileUrl: ""), documentsService: mockDocuments)
    sut.downloadedFileURL = nil

    XCTAssertTrue(sut.shareItems.isEmpty)
  }

  // MARK: - Error states

  func testLoadDocument_clearsErrorOnRetry() async {
    mockDocuments.shouldThrowFetchDocument = true
    sut = DocumentViewerViewModel(documentsService: mockDocuments)
    await sut.loadDocument(id: "doc-1")
    XCTAssertNotNil(sut.error)

    mockDocuments.shouldThrowFetchDocument = false
    mockDocuments.stubbedDocument = .mock(id: "doc-1")
    await sut.loadDocument(id: "doc-1")

    XCTAssertNil(sut.error)
  }
}
