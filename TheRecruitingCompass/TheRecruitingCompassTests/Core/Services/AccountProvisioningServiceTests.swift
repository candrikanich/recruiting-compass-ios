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
      details.graduationYear = 2028
      return details
    }()

    await sut.flushPendingOnboardingStep1()

    XCTAssertEqual(mockPreferenceService.saveCallCount, 0)
  }

  // Sport and grad year are independently idempotent: an already-set sport must not
  // block filling in a still-missing grad year (or vice versa).
  func testFillsInMissingGraduationYearWhenSportAlreadySet() async {
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

    XCTAssertEqual(mockPreferenceService.savedPlayerDetails?.primarySport, "Baseball")
    XCTAssertEqual(mockPreferenceService.savedPlayerDetails?.graduationYear, 2028)
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

  // A parent-invite signup may only pass sport (no grad year) or vice versa —
  // unlike self-signup step 1, which always collects both together. The flush
  // must not silently drop the field it does have (invite double-sport-prompt bug).
  func testFlushWritesSportOnlyWhenNoPendingGraduationYear() async {
    mockSupabaseManager.currentUserMetadataResult = [
      "pending_primary_sport": .string("Lacrosse")
    ]

    await sut.flushPendingOnboardingStep1()

    XCTAssertEqual(mockPreferenceService.savedPlayerDetails?.primarySport, "Lacrosse")
    XCTAssertNil(mockPreferenceService.savedPlayerDetails?.graduationYear)
  }

  func testFlushWritesGraduationYearOnlyWhenNoPendingSport() async {
    mockSupabaseManager.currentUserMetadataResult = [
      "pending_graduation_year": .string("2029")
    ]

    await sut.flushPendingOnboardingStep1()

    XCTAssertEqual(mockPreferenceService.savedPlayerDetails?.graduationYear, 2029)
    XCTAssertNil(mockPreferenceService.savedPlayerDetails?.primarySport)
  }

  func testIdempotentWhenGraduationYearAlreadySetAndOnlySportPending() async {
    mockSupabaseManager.currentUserMetadataResult = [
      "pending_primary_sport": .string("Lacrosse")
    ]
    mockPreferenceService.stubbedPlayerDetails = {
      var details = PlayerDetails.default
      details.primarySport = "Soccer"
      return details
    }()

    await sut.flushPendingOnboardingStep1()

    XCTAssertEqual(mockPreferenceService.saveCallCount, 0)
  }
}
