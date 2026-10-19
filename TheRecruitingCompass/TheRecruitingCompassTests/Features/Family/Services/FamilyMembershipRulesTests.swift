import XCTest
@testable import TheRecruitingCompass

/// Wire contract for GET /api/family/members, POST /api/family/leave and DELETE /api/family/members/:id
/// error codes (web#1262 / #1268 / #1339). iOS shows the server's text and never recomputes the rules.
final class FamilyMembershipRulesTests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  private func makeClient() -> FamilyAPIClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    var client = FamilyAPIClient(
      session: URLSession(configuration: config),
      baseURL: URL(string: "https://api.test.invalid"),
      tokenProvider: { "tok-1" }
    )
    client.busyRetryDelay = .zero
    return client
  }

  private func respond(_ status: Int, _ body: String, capture: @escaping @Sendable (URLRequest) -> Void = { _ in }) {
    StubURLProtocol.handler = { request in
      capture(request)
      return (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
              Data(body.utf8))
    }
  }

  private static func body(of request: URLRequest) -> [String: Any]? {
    guard let stream = request.httpBodyStream else {
      return request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
      let count = stream.read(&buffer, maxLength: buffer.count)
      if count <= 0 { break }
      data.append(buffer, count: count)
    }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
  }

  // MARK: - Decoding

  func test_membersDetail_decodesServerVerdicts() throws {
    let json = #"""
    {"success":true,"familyId":"f1","count":2,"ownerUserId":"u-player",
     "permissions":{"canRegenerateCode":true,"canLeave":false},
     "leaveBlockedReason":"You're the only guardian.",
     "members":[
      {"id":"m1","family_unit_id":"f1","user_id":"u-player","role":"player","added_at":"2026-01-01T00:00:00Z",
       "users":{"id":"u-player","email":"p@x.com","full_name":"Pat","role":"player"},"canRemove":false},
      {"id":"m2","family_unit_id":"f1","user_id":"u-parent","role":"parent","added_at":"2026-01-02T00:00:00Z",
       "users":{"id":"u-parent","email":"g@x.com","full_name":"Gail","role":"parent"},
       "canRemove":false,"removeBlockedReason":"Only guardian."}]}
    """#
    let detail = try JSONDecoder().decode(FamilyMembersDetail.self, from: Data(json.utf8))

    XCTAssertEqual(detail.ownerUserId, "u-player")
    XCTAssertEqual(detail.canLeave, false)
    XCTAssertEqual(detail.leaveBlockedReason, "You're the only guardian.")
    XCTAssertEqual(detail.members.map(\.canRemove), [false, false])
    XCTAssertEqual(detail.members[1].removeBlockedReason, "Only guardian.")
    XCTAssertEqual(detail.members[1].user?.fullName, "Gail")
  }

  func test_membersDetail_decodesWithoutAnyNewFields() throws {
    let json = #"""
    {"success":true,"members":[{"id":"m1","family_unit_id":"f1","user_id":"u1","role":"parent",
     "added_at":"2026-01-01T00:00:00Z","users":{"id":"u1","email":"a@x.com","full_name":null,"role":"parent"}}]}
    """#
    let detail = try JSONDecoder().decode(FamilyMembersDetail.self, from: Data(json.utf8))

    XCTAssertNil(detail.canLeave)
    XCTAssertNil(detail.ownerUserId)
    XCTAssertNil(detail.leaveBlockedReason)
    XCTAssertNil(detail.members[0].canRemove)
    XCTAssertNil(detail.members[0].removeBlockedReason)
  }

  // MARK: - Request shapes

  func test_fetchMembers_getsWithFamilyIdQuery() async throws {
    nonisolated(unsafe) var captured: URLRequest?
    respond(200, #"{"members":[]}"#) { captured = $0 }

    _ = try await makeClient().fetchMembers(familyId: "fam-1")

    XCTAssertEqual(captured?.httpMethod, "GET")
    XCTAssertEqual(captured?.url?.path, "/api/family/members")
    XCTAssertEqual(captured?.url?.query, "familyId=fam-1")
    XCTAssertEqual(captured?.value(forHTTPHeaderField: "X-Client-Platform"), "ios")
  }

  func test_leave_postsFamilyIdWithoutConfirmFlagByDefault() async throws {
    nonisolated(unsafe) var captured: URLRequest?
    respond(200, #"{"success":true,"outcome":"left"}"#) { captured = $0 }

    let outcome = try await makeClient().leaveFamily(familyId: "fam-1", confirmDeleteFamily: false)

    XCTAssertEqual(outcome, .left)
    XCTAssertEqual(captured?.httpMethod, "POST")
    XCTAssertEqual(captured?.url?.path, "/api/family/leave")
    XCTAssertEqual(captured?.value(forHTTPHeaderField: "Authorization"), "Bearer tok-1")
    XCTAssertEqual(captured?.value(forHTTPHeaderField: "X-Client-Platform"), "ios")
    let body = captured.flatMap(Self.body(of:))
    XCTAssertEqual(body?["familyId"] as? String, "fam-1")
    XCTAssertNil(body?["confirmDeleteFamily"])
  }

  func test_leave_confirmedSendsConfirmDeleteFamilyTrue_andDecodesFamilyDeleted() async throws {
    nonisolated(unsafe) var captured: URLRequest?
    respond(200, #"{"success":true,"outcome":"family_deleted"}"#) { captured = $0 }

    let outcome = try await makeClient().leaveFamily(familyId: "fam-1", confirmDeleteFamily: true)

    XCTAssertEqual(outcome, .familyDeleted)
    XCTAssertEqual(captured.flatMap(Self.body(of:))?["confirmDeleteFamily"] as? Bool, true)
  }

  // MARK: - Error mapping (server text is always shown)

  func test_leave_lastGuardianOfMinor403_surfacesServerMessage() async {
    respond(403, #"{"statusMessage":"Invite another guardian first.","data":{"code":"last_guardian_of_minor"}}"#)
    await assertLeaveFails(withMessage: "Invite another guardian first.")
  }

  func test_leave_noEligibleOwner409_surfacesServerMessage() async {
    respond(409, #"{"statusMessage":"Pick an owner first.","message":"Pick an owner first.","data":{"code":"no_eligible_owner"}}"#)
    await assertLeaveFails(withMessage: "Pick an owner first.")
  }

  func test_leave_playerLeaveRefused403_surfacesServerMessage() async {
    respond(403, #"{"statusMessage":"Players can't leave a family."}"#)
    await assertLeaveFails(withMessage: "Players can't leave a family.")
  }

  func test_leave_lastMemberConfirmation409_throwsConfirmationCaseWithServerWarning() async {
    respond(409, #"{"message":"Leaving deletes the family.","data":{"code":"last_member_confirmation_required"}}"#)
    do {
      _ = try await makeClient().leaveFamily(familyId: "fam-1", confirmDeleteFamily: false)
      XCTFail("expected throw")
    } catch FamilyError.lastMemberConfirmationRequired(let warning) {
      XCTAssertEqual(warning, "Leaving deletes the family.")
    } catch {
      XCTFail("wrong error \(error)")
    }
  }

  func test_remove_notPermitted403_surfacesServerMessage() async {
    respond(403, #"{"message":"You aren't allowed to remove this member.","data":{"code":"removal_not_permitted"}}"#)
    do {
      try await makeClient().removeMember(memberId: "m1")
      XCTFail("expected throw")
    } catch {
      XCTAssertEqual(error.localizedDescription, "You aren't allowed to remove this member.")
    }
  }

  func test_remove_unknownMember404_surfacesServerMessage() async {
    respond(404, #"{"message":"Member not found"}"#)
    do {
      try await makeClient().removeMember(memberId: "m1")
      XCTFail("expected throw")
    } catch {
      XCTAssertEqual(error.localizedDescription, "Member not found")
    }
  }

  func test_busyRetry_retriesOnceThenSucceeds() async throws {
    nonisolated(unsafe) var calls = 0
    StubURLProtocol.handler = { request in
      calls += 1
      let busy = calls == 1
      let body = busy ? #"{"message":"Try again.","data":{"code":"family_busy_retry"}}"# : #"{"success":true}"#
      return (HTTPURLResponse(url: request.url!, statusCode: busy ? 409 : 200, httpVersion: nil,
                              headerFields: nil)!, Data(body.utf8))
    }

    try await makeClient().removeMember(memberId: "m1")

    XCTAssertEqual(calls, 2)
  }

  func test_busyRetry_persistentBusy_throwsRetryableCaseAfterOneRetry() async {
    nonisolated(unsafe) var calls = 0
    StubURLProtocol.handler = { request in
      calls += 1
      return (HTTPURLResponse(url: request.url!, statusCode: 409, httpVersion: nil, headerFields: nil)!,
              Data(#"{"message":"Someone else just changed this family. Please try again.","data":{"code":"family_busy_retry"}}"#.utf8))
    }
    do {
      try await makeClient().removeMember(memberId: "m1")
      XCTFail("expected throw")
    } catch FamilyError.busyRetry(let message) {
      XCTAssertEqual(message, "Someone else just changed this family. Please try again.")
      XCTAssertEqual(calls, 2)
    } catch {
      XCTFail("wrong error \(error)")
    }
  }

  private func assertLeaveFails(withMessage message: String, file: StaticString = #filePath, line: UInt = #line) async {
    do {
      _ = try await makeClient().leaveFamily(familyId: "fam-1", confirmDeleteFamily: false)
      XCTFail("expected throw", file: file, line: line)
    } catch {
      XCTAssertEqual(error.localizedDescription, message, file: file, line: line)
    }
  }
}
