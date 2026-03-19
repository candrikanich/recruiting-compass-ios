import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AuthManagerBiometricTests: XCTestCase {
  nonisolated deinit {}
  var sut: AuthManager!
  var mockBiometricService: MockBiometricService!
  var mockSupabaseManager: MockSupabaseManager!
  private let biometricEnabledKey = "biometricEnabled"

  override func setUp() {
    super.setUp()
    mockBiometricService = MockBiometricService()
    mockSupabaseManager = MockSupabaseManager()
    sut = AuthManager(supabaseManager: mockSupabaseManager, biometricService: mockBiometricService)
    try? KeychainHelper.shared.delete(forKey: biometricEnabledKey)
  }

  override func tearDown() {
    try? KeychainHelper.shared.delete(forKey: biometricEnabledKey)
    sut = nil
    mockBiometricService = nil
    mockSupabaseManager = nil
    super.tearDown()
  }

  // MARK: - biometricEnabled flag

  func testBiometricEnabledDefaultsFalse() {
    XCTAssertFalse(sut.biometricEnabled)
  }

  func testEnableBiometricsSetsFlag() throws {
    try sut.enableBiometrics()
    XCTAssertTrue(sut.biometricEnabled)
  }

  func testDisableBiometricsClearsFlag() throws {
    try sut.enableBiometrics()
    sut.disableBiometrics()
    XCTAssertFalse(sut.biometricEnabled)
  }

  // MARK: - logout clears biometric

  func testLogoutClearsBiometricFlag() async throws {
    try sut.enableBiometrics()
    XCTAssertTrue(sut.biometricEnabled)

    try await sut.logout()

    XCTAssertFalse(sut.biometricEnabled)
  }

  // MARK: - authenticateWithBiometrics

  func testAuthenticateWithBiometricsCallsService() async throws {
    try await sut.authenticateWithBiometrics()
    XCTAssertEqual(mockBiometricService.authenticateCallCount, 1)
  }

  func testAuthenticateWithBiometricsThrowsOnFailure() async {
    mockBiometricService.authenticateResult = .failure(BiometricError.failed)

    do {
      try await sut.authenticateWithBiometrics()
      XCTFail("Expected throw")
    } catch {
      XCTAssertTrue(error is BiometricError)
    }
  }

  func testAuthenticateWithBiometricsThrowsOnLockout() async {
    mockBiometricService.authenticateResult = .failure(BiometricError.lockout)

    do {
      try await sut.authenticateWithBiometrics()
      XCTFail("Expected throw")
    } catch let error as BiometricError {
      XCTAssertEqual(error, BiometricError.lockout)
    } catch {
      XCTFail("Wrong error type: \(error)")
    }
  }
}
