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
        let result = try await service.fetchProfile(athleteId: nil, accessToken: nil)
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
        let result = try await service.fetchProfile(athleteId: nil, accessToken: "tok")
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

    // MARK: - Parent delegate (ios#360)

    private func okResponse(_ request: URLRequest, _ body: Data = Data("{}".utf8)) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
    }

    func testFetchProfileSendsAthleteIdQuery() async throws {
        var seenQuery: String?
        StubURLProtocol.handler = { [self] request in
            seenQuery = request.url?.query
            return okResponse(request, Data())
        }
        let service = PublicProfileServiceImpl(
            session: makeSession(), baseURLOverride: URL(string: "https://test.local")!
        )
        _ = try await service.fetchProfile(athleteId: "athlete-9", accessToken: "tok")
        XCTAssertEqual(seenQuery, "athleteId=athlete-9")
    }

    func testFetchProfileOmitsAthleteIdForPlayer() async throws {
        var seenQuery: String? = "unset"
        StubURLProtocol.handler = { [self] request in
            seenQuery = request.url?.query
            return okResponse(request, Data())
        }
        let service = PublicProfileServiceImpl(
            session: makeSession(), baseURLOverride: URL(string: "https://test.local")!
        )
        _ = try await service.fetchProfile(athleteId: nil, accessToken: "tok")
        XCTAssertNil(seenQuery)
    }

    func testTrackingLinkRequestsCarryAthleteIdQuery() async throws {
        seedCSRFCookie()
        var seen: [URL] = []
        StubURLProtocol.handler = { [self] request in
            if request.url?.path.contains("tracking-links") == true {
                seen.append(request.url!)
            }
            let link = #"{"id":"t1","profile_id":"p1","coach_id":"c1","ref_token":"r","view_count":0,"created_at":""}"#
            return okResponse(request, Data(link.utf8))
        }
        let service = PublicProfileServiceImpl(
            session: makeSession(), baseURLOverride: URL(string: "https://test.local")!
        )
        _ = try await service.fetchTrackingLink(coachId: "c1", athleteId: "athlete-9", accessToken: "tok")
        _ = try await service.createTrackingLink(coachId: "c1", athleteId: "athlete-9", accessToken: "tok")
        XCTAssertEqual(seen.map(\.query), ["athleteId=athlete-9", "athleteId=athlete-9"])
        let expectedPath = "/api/player/profile/tracking-links/c1"
        XCTAssertEqual(seen.map(\.path), [expectedPath, expectedPath])
    }

    func testTrackingLinkRequestsOmitAthleteIdForPlayer() async throws {
        seedCSRFCookie()
        var queries: [String?] = []
        StubURLProtocol.handler = { [self] request in
            if request.url?.path.contains("tracking-links") == true { queries.append(request.url?.query) }
            let link = #"{"id":"t1","profile_id":"p1","coach_id":"c1","ref_token":"r","view_count":0,"created_at":""}"#
            return okResponse(request, Data(link.utf8))
        }
        let service = PublicProfileServiceImpl(
            session: makeSession(), baseURLOverride: URL(string: "https://test.local")!
        )
        _ = try await service.fetchTrackingLink(coachId: "c1", athleteId: nil, accessToken: "tok")
        _ = try await service.createTrackingLink(coachId: "c1", athleteId: nil, accessToken: "tok")
        XCTAssertEqual(queries.count, 2)
        XCTAssertTrue(queries.allSatisfy { $0 == nil })
    }

    private func makeService(familyUnitId: String?) -> PublicProfileServiceImpl {
        PublicProfileServiceImpl(
            session: makeSession(),
            baseURLOverride: URL(string: "https://test.local")!,
            familyUnitIdProvider: { familyUnitId }
        )
    }

    private let trackingLinkJSON =
        #"{"id":"t1","profile_id":"p1","coach_id":"c1","ref_token":"r","view_count":0,"created_at":""}"#

    func testTrackingLinkRequestsCarryFamilyUnitId() async throws {
        seedCSRFCookie()
        var queries: [[URLQueryItem]] = []
        StubURLProtocol.handler = { [self] request in
            if request.url?.path.contains("tracking-links") == true {
                let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
                queries.append(items)
            }
            return okResponse(request, Data(trackingLinkJSON.utf8))
        }
        let service = makeService(familyUnitId: "fam-1")
        _ = try await service.fetchTrackingLink(coachId: "c1", athleteId: "athlete-9", accessToken: "tok")
        _ = try await service.createTrackingLink(coachId: "c1", athleteId: "athlete-9", accessToken: "tok")
        XCTAssertEqual(queries.count, 2)
        for items in queries {
            XCTAssertEqual(items.first { $0.name == "familyUnitId" }?.value, "fam-1")
            XCTAssertEqual(items.first { $0.name == "athleteId" }?.value, "athlete-9")
        }
    }

    func testTrackingLinkRequestsNeverSendEmptyFamilyUnitId() async throws {
        seedCSRFCookie()
        var queries: [String?] = []
        StubURLProtocol.handler = { [self] request in
            if request.url?.path.contains("tracking-links") == true { queries.append(request.url?.query) }
            return okResponse(request, Data(trackingLinkJSON.utf8))
        }
        for blank in [nil, "", "  "] {
            let service = makeService(familyUnitId: blank)
            _ = try await service.fetchTrackingLink(coachId: "c1", athleteId: nil, accessToken: "tok")
            _ = try await service.createTrackingLink(coachId: "c1", athleteId: nil, accessToken: "tok")
        }
        XCTAssertEqual(queries.count, 6)
        XCTAssertTrue(queries.allSatisfy { $0 == nil })
    }

    func testTrackingLinkMapsFamilyContextErrorCodes() async {
        seedCSRFCookie()
        let cases: [(String, PublicProfileAPIError)] = [
            ("family_context_required", .familyContextRequired),
            ("invalid_family_context", .invalidFamilyContext)
        ]
        let expectedCopy = "Couldn't make the tracking link for this family. "
            + "Pick the family in the switcher and try again."
        for (code, expected) in cases {
            StubURLProtocol.handler = { [self] request in
                guard request.url?.path.contains("tracking-links") == true else { return okResponse(request) }
                let body = Data(#"{"statusCode":400,"message":"raw","data":{"code":"\#(code)"}}"#.utf8)
                return (HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!, body)
            }
            let service = makeService(familyUnitId: "fam-1")
            let calls: [(String, () async throws -> Void)] = [
                ("fetch", { _ = try await service.fetchTrackingLink(coachId: "c1", athleteId: nil, accessToken: "t") }),
                ("create", { _ = try await service.createTrackingLink(coachId: "c1", athleteId: nil, accessToken: "t") }
                )
            ]
            for (name, call) in calls {
                do {
                    try await call()
                    XCTFail("expected throw for \(name) \(code)")
                } catch {
                    XCTAssertEqual(error as? PublicProfileAPIError, expected, "\(name) \(code)")
                    XCTAssertEqual((error as? LocalizedError)?.errorDescription, expectedCopy)
                }
            }
        }
    }

    func testTrackingLink403ThrowsRatherThanReturningData() async {
        StubURLProtocol.handler = { request in
            let body = Data(#"{"statusCode":403,"message":"Not a member of this family"}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!, body)
        }
        do {
            _ = try await makeService(familyUnitId: "fam-1")
                .fetchTrackingLink(coachId: "c1", athleteId: nil, accessToken: "tok")
            XCTFail("expected throw")
        } catch {
            XCTAssertNotNil((error as? LocalizedError)?.errorDescription)
        }
    }

    func testUpdateSendsAthleteIdInBody() async throws {
        seedCSRFCookie()
        var putBody: [String: Any]?
        StubURLProtocol.handler = { [self] request in
            if request.httpMethod == "PUT", let stream = request.httpBodyStream {
                stream.open()
                var data = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    data.append(buffer, count: count)
                }
                putBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
            return okResponse(request)
        }
        let service = PublicProfileServiceImpl(
            session: makeSession(), baseURLOverride: URL(string: "https://test.local")!
        )
        let payload = UpdateProfilePayload(bio: .some("hi"), athleteId: "athlete-9")
        try await service.updateProfile(payload, accessToken: "tok")
        XCTAssertEqual(putBody?["athleteId"] as? String, "athlete-9")
    }

    func testUpdateSurfacesServerMessageOn403() async {
        seedCSRFCookie()
        StubURLProtocol.handler = { [self] request in
            if request.httpMethod == "PUT" {
                let body = Data(#"{"statusCode":403,"message":"Not authorized to edit this athlete's profile"}"#.utf8)
                return (HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!, body)
            }
            return okResponse(request)
        }
        let service = PublicProfileServiceImpl(
            session: makeSession(), baseURLOverride: URL(string: "https://test.local")!
        )
        do {
            try await service.updateProfile(UpdateProfilePayload(athleteId: "athlete-9"), accessToken: "tok")
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(
                (error as? LocalizedError)?.errorDescription,
                "Not authorized to edit this athlete's profile"
            )
        }
    }

    func testUpdateSurfacesServerMessageOn404() async {
        seedCSRFCookie()
        StubURLProtocol.handler = { [self] request in
            if request.httpMethod == "PUT" {
                let body = Data(#"{"message":"No profile found to update"}"#.utf8)
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, body)
            }
            return okResponse(request)
        }
        let service = PublicProfileServiceImpl(
            session: makeSession(), baseURLOverride: URL(string: "https://test.local")!
        )
        do {
            try await service.updateProfile(UpdateProfilePayload(), accessToken: "tok")
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual((error as? LocalizedError)?.errorDescription, "No profile found to update")
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
