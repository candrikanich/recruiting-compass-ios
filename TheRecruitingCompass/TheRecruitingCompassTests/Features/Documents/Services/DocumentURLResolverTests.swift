import XCTest
@testable import TheRecruitingCompass

final class DocumentURLResolverTests: XCTestCase {
  nonisolated deinit {}

  private let origin = URL(string: "https://proj.supabase.co")!
  private let publicPrefix = "https://proj.supabase.co/storage/v1/object/public/documents/"

  private func classify(_ raw: String) -> DocumentFileLocation {
    DocumentFileLocation.classify(raw, supabaseOrigin: origin)
  }

  // MARK: - classify

  func testBarePath_isStoragePath() {
    XCTAssertEqual(classify("u1/resume/123_cv.pdf"), .storagePath("u1/resume/123_cv.pdf"))
  }

  func testOwnPublicURL_mapsToObjectPath() {
    XCTAssertEqual(classify(publicPrefix + "u1/resume/1_my%20cv.pdf?t=1"), .storagePath("u1/resume/1_my cv.pdf"))
  }

  func testForeignHTTPS_opensUnchanged() {
    let raw = "https://example.com/file.pdf"
    XCTAssertEqual(classify(raw), .external(URL(string: raw)!))
  }

  func testOtherSchemes_areRejected() {
    for raw in ["javascript:alert(1)", "file:///etc/passwd", "data:text/html,x", " javascript:x", "java\tscript:x"] {
      XCTAssertEqual(classify(raw), .rejected, raw)
    }
  }

  func testTraversal_isRejected() {
    for raw in ["../other/x.pdf", "u1/../x.pdf", "u1/%2e%2e/x.pdf", "u1/.\t./x.pdf", publicPrefix + "u1/%2e%2e/x.pdf"] {
      XCTAssertEqual(classify(raw), .rejected, raw)
    }
  }

  func testControlCharactersAndQueryInBarePath_areRejected() {
    for raw in ["u1/a\u{0}b.pdf", "u1/a?b.pdf", "u1/a#b.pdf", ""] {
      XCTAssertEqual(classify(raw), .rejected, raw)
    }
  }

  func testOwnOriginOutsideDocumentsBucket_isRejected() {
    XCTAssertEqual(classify("https://proj.supabase.co/storage/v1/object/public/avatars/u1/a.png"), .rejected)
  }

  // MARK: - resolver

  func testStoragePath_isSignedNotPublic() async throws {
    let signed = URL(string: "https://proj.supabase.co/storage/v1/object/sign/documents/u1/a.pdf?token=t")!
    let recorder = PathRecorder()
    let sut = DocumentURLResolver(supabaseOrigin: origin) { path in
      await recorder.record(path)
      return signed
    }

    let url = try await sut.openableURL(for: publicPrefix + "u1/a.pdf")

    XCTAssertEqual(url, signed)
    let paths = await recorder.paths
    XCTAssertEqual(paths, ["u1/a.pdf"])
  }

  func testSigningFailure_throwsAndNeverFallsBackToPublicURL() async {
    let sut = DocumentURLResolver(supabaseOrigin: origin) { _ in throw URLError(.notConnectedToInternet) }

    do {
      let url = try await sut.openableURL(for: "u1/a.pdf")
      XCTFail("expected failure, got \(url)")
    } catch {
      XCTAssertTrue(error is URLError)
    }
  }

  func testExternalURL_isNotSigned() async throws {
    let origin = self.origin
    let sut = DocumentURLResolver(supabaseOrigin: origin) { _ in
      XCTFail("must not sign an external URL")
      return origin
    }

    let url = try await sut.openableURL(for: "https://example.com/a.pdf")

    XCTAssertEqual(url.absoluteString, "https://example.com/a.pdf")
  }

  func testRejectedValue_throwsNotOpenable() async {
    let origin = self.origin
    let sut = DocumentURLResolver(supabaseOrigin: origin) { _ in origin }

    do {
      _ = try await sut.openableURL(for: "javascript:alert(1)")
      XCTFail("expected notOpenable")
    } catch {
      XCTAssertEqual(error as? DocumentURLError, .notOpenable)
    }
  }

  func testSignerReturningNonHTTP_isRefused() async {
    let sut = DocumentURLResolver(supabaseOrigin: origin) { _ in URL(string: "file:///tmp/x")! }

    do {
      _ = try await sut.openableURL(for: "u1/a.pdf")
      XCTFail("expected notOpenable")
    } catch {
      XCTAssertEqual(error as? DocumentURLError, .notOpenable)
    }
  }
}

private actor PathRecorder {
  private(set) var paths: [String] = []
  func record(_ path: String) { paths.append(path) }
}
