import XCTest
@testable import TheRecruitingCompass

final class DocumentCollectionTests: XCTestCase {

  private var docs: [Document]!

  override func setUp() {
    super.setUp()
    docs = [
      Document.mock(id: "doc-1", title: "First"),
      Document.mock(id: "doc-2", title: "Second"),
      Document.mock(id: "doc-3", title: "Third")
    ]
  }

  override func tearDown() {
    docs = nil
    super.tearDown()
  }

  // MARK: - currentDocument

  func testCurrentDocument_returnsDocumentAtIndex() {
    let collection = DocumentCollection(documents: docs, currentIndex: 0)
    XCTAssertEqual(collection.currentDocument.id, "doc-1")
    XCTAssertEqual(collection.currentDocument.title, "First")
  }

  func testCurrentDocument_middleIndex_returnsCorrectDocument() {
    let collection = DocumentCollection(documents: docs, currentIndex: 1)
    XCTAssertEqual(collection.currentDocument.id, "doc-2")
  }

  func testCurrentDocument_lastIndex_returnsLastDocument() {
    let collection = DocumentCollection(documents: docs, currentIndex: 2)
    XCTAssertEqual(collection.currentDocument.id, "doc-3")
  }

  // MARK: - hasNext / hasPrevious

  func testHasNext_atStart_returnsTrue() {
    let collection = DocumentCollection(documents: docs, currentIndex: 0)
    XCTAssertTrue(collection.hasNext)
  }

  func testHasNext_inMiddle_returnsTrue() {
    let collection = DocumentCollection(documents: docs, currentIndex: 1)
    XCTAssertTrue(collection.hasNext)
  }

  func testHasNext_atEnd_returnsFalse() {
    let collection = DocumentCollection(documents: docs, currentIndex: 2)
    XCTAssertFalse(collection.hasNext)
  }

  func testHasNext_singleDocument_returnsFalse() {
    let single = DocumentCollection(documents: [docs[0]], currentIndex: 0)
    XCTAssertFalse(single.hasNext)
  }

  func testHasPrevious_atStart_returnsFalse() {
    let collection = DocumentCollection(documents: docs, currentIndex: 0)
    XCTAssertFalse(collection.hasPrevious)
  }

  func testHasPrevious_inMiddle_returnsTrue() {
    let collection = DocumentCollection(documents: docs, currentIndex: 1)
    XCTAssertTrue(collection.hasPrevious)
  }

  func testHasPrevious_atEnd_returnsTrue() {
    let collection = DocumentCollection(documents: docs, currentIndex: 2)
    XCTAssertTrue(collection.hasPrevious)
  }

  func testHasPrevious_singleDocument_returnsFalse() {
    let single = DocumentCollection(documents: [docs[0]], currentIndex: 0)
    XCTAssertFalse(single.hasPrevious)
  }

  // MARK: - nextDocument / previousDocument

  func testNextDocument_hasNext_returnsNextDocument() {
    let collection = DocumentCollection(documents: docs, currentIndex: 0)
    let next = collection.nextDocument()
    XCTAssertEqual(next?.id, "doc-2")
  }

  func testNextDocument_atEnd_returnsNil() {
    let collection = DocumentCollection(documents: docs, currentIndex: 2)
    let next = collection.nextDocument()
    XCTAssertNil(next)
  }

  func testPreviousDocument_hasPrevious_returnsPreviousDocument() {
    let collection = DocumentCollection(documents: docs, currentIndex: 2)
    let prev = collection.previousDocument()
    XCTAssertEqual(prev?.id, "doc-2")
  }

  func testPreviousDocument_atStart_returnsNil() {
    let collection = DocumentCollection(documents: docs, currentIndex: 0)
    let prev = collection.previousDocument()
    XCTAssertNil(prev)
  }
}
