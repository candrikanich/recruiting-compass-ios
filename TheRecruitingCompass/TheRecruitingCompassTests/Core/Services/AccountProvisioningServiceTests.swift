import XCTest
import Helpers
@testable import TheRecruitingCompass

@MainActor
final class AccountProvisioningServiceTests: XCTestCase {
  nonisolated deinit {}
  var sut: AccountProvisioningService!
  var mockSupabaseManager: MockSupabaseManager!
  var mockPreferenceService: MockPreferenceService!

  override func setUp() {
    super.setUp()
    mockSupabaseManager = MockSupabaseManager()
    mockPreferenceService = MockPreferenceService()
    sut = AccountProvisioningService(supabaseManager: mockSupabaseManager, preferenceService: mockPreferenceService)
  }

  override func tearDown() {
    sut = nil
    mockSupabaseManager = nil
    mockPreferenceService = nil
    super.tearDown()
  }

  func testNoOpWhenNoPendingMetadata() async {
    mockSupabaseManager.currentUserMetadataResult = [:]

    await sut.flushPendingOnboardingStep1()

    XCTAssertEqual(mockPreferenceService.saveCallCount, 0)
  }

  func testNoOpWhenNoSession() async {
    mockSupabaseManager.currentUserMetadataResult = nil

    await sut.flushPendingOnboardingStep1()

    XCTAssertEqual(mockPreferenceService.saveCallCount, 0)
  }

  func testFlushWritesPlayerDetailsAndLocation() async {
    mockSupabaseManager.currentUserMetadataResult = [
      "pending_graduation_year": .string("2028"),
      "pending_primary_sport": .string("Soccer"),
      "pending_gender": .string("female"),
      "pending_zip_code": .string("94105")
    ]

    await sut.flushPendingOnboardingStep1()

    XCTAssertEqual(mockPreferenceService.savedPlayerDetails?.primarySport, "Soccer")
    XCTAssertEqual(mockPreferenceService.savedPlayerDetails?.graduationYear, 2028)
    XCTAssertEqual(mockPreferenceService.savedPlayerDetails?.gender, "female")
    XCTAssertEqual(mockPreferenceService.savedHomeLocation?.zip, "94105")
  }

  func testFlushSkipsLocationWriteWhenNoZip() async {
    mockSupabaseManager.currentUserMetadataResult = [
      "pending_graduation_year": .string("2028"),
      "pending_primary_sport": .string("Baseball")
    ]

    await sut.flushPendingOnboardingStep1()

    XCTAssertNotNil(mockPreferenceService.savedPlayerDetails)
    XCTAssertNil(mockPreferenceService.savedHomeLocation)
  }

  func testIdempotentWhenPrimarySportAlreadySet() async {
    mockSupabaseManager.currentUserMetadataResult = [
      "pending_graduation_year": .string("2028"),
      "pending_primary_sport": .string("Soccer")
    ]
    mockPreferenceService.stubbedPlayerDetails = {
      var details = PlayerDetails.default
      details.primarySport = "Baseball"
      return details
    }()

    await sut.flushPendingOnboardingStep1()

    XCTAssertEqual(mockPreferenceService.saveCallCount, 0)
  }

  func testSwallowsErrorsWithoutThrowing() async {
    mockSupabaseManager.currentUserMetadataResult = [
      "pending_graduation_year": .string("2028"),
      "pending_primary_sport": .string("Soccer")
    ]
    mockPreferenceService.errorToThrow = AuthError.networkError("boom")

    // Must not throw or crash — sign-in/confirmation must succeed regardless.
    await sut.flushPendingOnboardingStep1()
  }
}
