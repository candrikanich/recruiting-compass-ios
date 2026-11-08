import XCTest
@testable import TheRecruitingCompass

final class DocumentShareLinkTests: XCTestCase {
  private let origin = "https://proj.supabase.co"
  private let publicPrefix = "https://proj.supabase.co/storage/v1/object/public/documents/"

  // MARK: - Classification

  func test_barePathIsStorage() {
    XCTAssertEqual(DocumentLinkTarget.classify(fileURL: "uid/123-transcript.pdf", supabaseOrigin: origin), .storage)
  }

  func test_ownPublicBucketUrlIsStorage() {
    let url = publicPrefix + "uid/123-transcript.pdf"
    XCTAssertEqual(DocumentLinkTarget.classify(fileURL: url, supabaseOrigin: origin), .storage)
  }

  func test_externalHttpsUrlPassesThrough() {
    let url = "https://drive.example.com/transcript.pdf"
    XCTAssertEqual(DocumentLinkTarget.classify(fileURL: url, supabaseOrigin: origin), .external(url))
  }

  func test_otherUrlOnOurOriginIsNotPassedThrough() {
    let url = "https://proj.supabase.co/storage/v1/object/public/avatars/uid/a.png"
    XCTAssertEqual(DocumentLinkTarget.classify(fileURL: url, supabaseOrigin: origin), .none)
  }

  func test_traversalAndNonHttpSchemesYieldNone() {
    let bad = ["../other/secret.pdf", "uid/../x.pdf", "uid/%2e%2e/x.pdf", "javascript:alert(1)",
               "data:text/plain,hi", "uid/a?b.pdf", "", publicPrefix + "uid/%2e%2e/x.pdf"]
    for raw in bad {
      XCTAssertEqual(DocumentLinkTarget.classify(fileURL: raw, supabaseOrigin: origin), .none, raw)
    }
    XCTAssertEqual(DocumentLinkTarget.classify(fileURL: nil, supabaseOrigin: origin), .none)
  }

  // MARK: - Issuing

  func test_reusesActiveToken() async throws {
    let store = FakeShareTokenStore(active: [token("a")])
    let url = try await DocumentShareLinkService(store: store).shareURL(documentId: "doc1")
    XCTAssertEqual(url, "https://myrecruitingcompass.com/d/" + token("a"))
    XCTAssertEqual(store.insertedDocumentIds, [])
  }

  func test_insertsWhenNoActiveToken() async throws {
    let store = FakeShareTokenStore(active: [], inserted: token("b"))
    let url = try await DocumentShareLinkService(store: store).shareURL(documentId: "doc1")
    XCTAssertEqual(url, "https://myrecruitingcompass.com/d/" + token("b"))
    XCTAssertEqual(store.insertedDocumentIds, ["doc1"])
  }

  func test_uniqueViolationReselectsWinner() async throws {
    let store = FakeShareTokenStore(active: [], insertError: .uniqueViolation, activeAfterRace: [token("c")])
    let url = try await DocumentShareLinkService(store: store).shareURL(documentId: "doc1")
    XCTAssertEqual(url, "https://myrecruitingcompass.com/d/" + token("c"))
  }

  func test_otherInsertErrorPropagates() async {
    let store = FakeShareTokenStore(active: [], insertError: .other)
    do {
      _ = try await DocumentShareLinkService(store: store).shareURL(documentId: "doc1")
      XCTFail("expected throw")
    } catch {}
  }

  // MARK: - Resolution (never the bucket URL)

  func test_resolveStorageDocumentReturnsShareLinkNotStoredUrl() async {
    let store = FakeShareTokenStore(active: [token("a")])
    let link = await DocumentShareLinkService(store: store).linkForDocument(
      id: "doc1", fileURL: publicPrefix + "uid/t.pdf", supabaseOrigin: origin)
    XCTAssertEqual(link, "https://myrecruitingcompass.com/d/" + token("a"))
  }

  func test_resolveExternalPassesThroughWithoutTouchingStore() async {
    let store = FakeShareTokenStore(active: [token("a")])
    let link = await DocumentShareLinkService(store: store).linkForDocument(
      id: "doc1", fileURL: "https://drive.example.com/t.pdf", supabaseOrigin: origin)
    XCTAssertEqual(link, "https://drive.example.com/t.pdf")
    XCTAssertEqual(store.listCalls, 0)
  }

  func test_resolveIssueFailureYieldsNilNotBucketUrl() async {
    let store = FakeShareTokenStore(active: [], insertError: .other)
    let link = await DocumentShareLinkService(store: store).linkForDocument(
      id: "doc1", fileURL: publicPrefix + "uid/t.pdf", supabaseOrigin: origin)
    XCTAssertNil(link)
  }

  private func token(_ c: Character) -> String { String(repeating: c, count: 64) }
}

private final class FakeShareTokenStore: DocumentShareTokenStoring, @unchecked Sendable {
  enum InsertError { case uniqueViolation, other }
  private var active: [String]
  private let inserted: String?
  private let insertError: InsertError?
  private let activeAfterRace: [String]
  private(set) var insertedDocumentIds: [String] = []
  private(set) var listCalls = 0

  init(active: [String], inserted: String? = nil, insertError: InsertError? = nil,
       activeAfterRace: [String] = []) {
    self.active = active
    self.inserted = inserted
    self.insertError = insertError
    self.activeAfterRace = activeAfterRace
  }

  func activeTokens(documentId: String) async throws -> [String] {
    listCalls += 1
    return active
  }

  func insertToken(documentId: String) async throws -> String {
    insertedDocumentIds.append(documentId)
    switch insertError {
    case .uniqueViolation:
      active = activeAfterRace
      throw DocumentShareTokenError.uniqueViolation
    case .other: throw DocumentShareTokenError.other
    case nil: return inserted ?? ""
    }
  }
}
