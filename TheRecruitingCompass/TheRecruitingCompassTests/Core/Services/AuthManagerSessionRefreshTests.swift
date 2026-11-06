import XCTest
@testable import TheRecruitingCompass

/// Each `getCurrentSession()` on the real `SupabaseManager` reads the signed-in user's `users` row,
/// so these pin how many of them a refresh or a session restore costs.
@MainActor
final class AuthManagerSessionRefreshTests: XCTestCase {
  nonisolated deinit {}
  var sut: AuthManager!
  var mockSupabaseManager: MockSupabaseManager!

  override func setUp() async throws {
    try? KeychainHelper.shared.delete(forKey: "savedSession")
    mockSupabaseManager = MockSupabaseManager()
    sut = AuthManager(supabaseManager: mockSupabaseManager, accountProvisioning: MockAccountProvisioning())
    // init() restores in an unstructured Task; let it take its "no saved session" branch first so it
    // cannot race the session a test saves below.
    while sut.isCheckingSession { await Task.yield() }
  }

  override func tearDown() {
    try? KeychainHelper.shared.delete(forKey: "savedSession")
    sut = nil
    mockSupabaseManager = nil
  }

  // MARK: - refreshSession()

  func testRefreshSession_readsProfileOnce_andPublishesIt() async throws {
    mockSupabaseManager.currentSessionResult = makeSession(fullName: "Fresh Name")

    let user = try await sut.refreshSession()

    XCTAssertEqual(mockSupabaseManager.getCurrentSessionCallCount, 1)
    XCTAssertEqual(user.fullName, "Fresh Name")
    XCTAssertEqual(sut.user?.fullName, "Fresh Name")
    XCTAssertEqual(sut.session?.accessToken, "token")
  }

  func testRefreshSession_noSession_throws() async {
    mockSupabaseManager.currentSessionResult = nil

    do {
      _ = try await sut.refreshSession()
      XCTFail("Expected refreshSession to throw without a session")
    } catch {
      XCTAssertNotNil(sut.errorMessage)
    }
  }

  // MARK: - restoreSession()

  func testRestoreSession_validSavedSession_readsProfileOnce_andSignsIn() async throws {
    try KeychainHelper.shared.save(makeSession(fullName: "Cached Name"), forKey: "savedSession")
    mockSupabaseManager.currentSessionResult = makeSession(fullName: "Fresh Name")

    await sut.restoreSession()

    XCTAssertEqual(mockSupabaseManager.getCurrentSessionCallCount, 1)
    XCTAssertTrue(sut.isAuthenticated)
    XCTAssertEqual(sut.user?.fullName, "Fresh Name")
    XCTAssertFalse(sut.isCheckingSession)
  }

  func testRestoreSession_serverHasNoSession_clearsState() async throws {
    try KeychainHelper.shared.save(makeSession(fullName: "Cached Name"), forKey: "savedSession")
    mockSupabaseManager.currentSessionResult = nil

    await sut.restoreSession()

    XCTAssertFalse(sut.isAuthenticated)
    XCTAssertNil(sut.user)
    XCTAssertNil(try? KeychainHelper.shared.load(Session.self, forKey: "savedSession"))
  }

  func testRestoreSession_lookupFails_fallsBackToValidCachedSession() async throws {
    try KeychainHelper.shared.save(makeSession(fullName: "Cached Name"), forKey: "savedSession")
    mockSupabaseManager.currentSessionError = AuthError.networkError("offline")

    await sut.restoreSession()

    XCTAssertTrue(sut.isAuthenticated)
    XCTAssertEqual(sut.user?.fullName, "Cached Name")
  }

  func testRestoreSession_lookupFails_expiredCachedSession_clearsState() async throws {
    try KeychainHelper.shared.save(
      makeSession(fullName: "Cached Name", expiresIn: -3600), forKey: "savedSession"
    )
    mockSupabaseManager.currentSessionError = AuthError.networkError("offline")

    await sut.restoreSession()

    XCTAssertFalse(sut.isAuthenticated)
    XCTAssertNil(sut.user)
  }

  // A deleted auth user must not be let back in on the cached session.
  func testRestoreSession_sessionInvalid_clearsStateDespiteValidCache() async throws {
    try KeychainHelper.shared.save(makeSession(fullName: "Cached Name"), forKey: "savedSession")
    mockSupabaseManager.currentSessionError = AuthError.sessionInvalid

    await sut.restoreSession()

    XCTAssertFalse(sut.isAuthenticated)
    XCTAssertNil(sut.user)
    XCTAssertNil(try? KeychainHelper.shared.load(Session.self, forKey: "savedSession"))
  }

  // MARK: - Helpers

  private func makeSession(fullName: String, expiresIn: Int = 3600) -> Session {
    let user = User(
      id: "test-user-id", email: "user@example.com", emailConfirmedAt: nil,
      fullName: fullName, createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z",
      role: .player, dateOfBirth: nil
    )
    return Session(
      accessToken: "token", tokenType: "bearer", expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + expiresIn, refreshToken: "refresh", user: user
    )
  }
}
