import XCTest
@testable import TheRecruitingCompass

final class PublicProfileServiceImplTests: XCTestCase {
    nonisolated deinit {}

    override func tearDown() {
        StubURLProtocol.handler = nil
        HTTPCookieStorage.shared.cookies?
            .filter { $0.name == "csrf-token" }
            .forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        super.tearDown()
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func seedCSRFCookie() {
        let cookie = HTTPCookie(properties: [
            .domain: "test.local",
            .path: "/",
            .name: "csrf-token",
            .value: "test-csrf"
        ])!
        HTTPCookieStorage.shared.setCookie(cookie)
    }

    func testFetchProfileReturnsNilWhenTokenMissing() async throws {
        let service = PublicProfileServiceImpl(session: makeSession())
        let result = try await service.fetchProfile(accessToken: nil)
        XCTAssertNil(result)  // no token → treated as unconfigured, no throw
    }

    func testFetchProfileDecodes200() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
            let body = """
            {"id":"p1","user_id":"u1","family_unit_id":"f1","hash_slug":"ab12cd",
             "vanity_slug":null,"is_published":true,"bio":"hi","header_color":"blue",
             "show_academics":true,"show_athletic":true,"show_film":true,"show_schools":true,
             "created_at":"","updated_at":""}
            """.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let service = PublicProfileServiceImpl(
            session: makeSession(), baseURLOverride: URL(string: "https://test.local")!
        )
        let result = try await service.fetchProfile(accessToken: "tok")
        XCTAssertEqual(result?.headerColor, "blue")
        XCTAssertTrue(result?.isPublished == true)
    }

    func testUpdateMaps409ToSlugTaken() async {
        seedCSRFCookie()
        StubURLProtocol.handler = { request in
            // csrf-token GET then PUT: return 200 for csrf, 409 for the PUT
            if request.url!.path.hasSuffix("/csrf-token") {
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("{}".utf8)
                )
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 409, httpVersion: nil, headerFields: nil)!, Data())
        }
        let service = PublicProfileServiceImpl(
            session: makeSession(), baseURLOverride: URL(string: "https://test.local")!
        )
        do {
            try await service.updateProfile(UpdateProfilePayload(vanitySlug: "taken"), accessToken: "tok")
            XCTFail("expected throw")
        } catch let e as PublicProfileAPIError {
            XCTAssertEqual(e, .slugTaken)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}

/// Minimal URLProtocol stub for injecting HTTP responses in tests.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = StubURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
