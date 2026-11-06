import XCTest
@testable import TheRecruitingCompass

/// Prod: both demo families (and two legacy ones) had family_code NULL, so the code card spun forever.
@MainActor
final class FamilyManagementViewModelFamilyCodeTests: XCTestCase {
  nonisolated deinit {}

  private var sut: FamilyManagementViewModel!
  private var mockFamilyService: MockFamilyService!
  private var mockAuthManager: MockAuthManager!

  override func setUp() async throws {
    mockFamilyService = MockFamilyService()
    mockAuthManager = MockAuthManager()
    sut = FamilyManagementViewModel(
      familyService: mockFamilyService,
      authManager: mockAuthManager,
      inboundDraftsService: MockInboundDraftsAPIService()
    )
  }

  override func tearDown() async throws {
    sut = nil
    mockFamilyService = nil
    mockAuthManager = nil
  }

  private func makeUser() -> User {
    User(
      id: "user-1",
      email: "test@test.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      fullName: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: .player,
      dateOfBirth: nil
    )
  }

  private func makeFamilyUnit(familyCode: String?) -> FamilyUnit {
    FamilyUnit(
      id: "family-1",
      createdByUserId: "user-1",
      familyName: "Test Family",
      familyCode: familyCode,
      codeGeneratedAt: familyCode == nil ? nil : "2024-01-01T00:00:00Z",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      homeLatitude: nil,
      homeLongitude: nil
    )
  }

  func testLoadData_asPlayer_familyWithoutCode_generatesOne() async {
    mockAuthManager.setMockUser(makeUser())
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit(familyCode: nil)

    await sut.loadData()

    XCTAssertEqual(mockFamilyService.regenerateCodeCallCount, 1)
    XCTAssertEqual(mockFamilyService.lastFamilyIdRegenerated, "family-1")
    XCTAssertEqual(sut.familyCode, "FAM-XYZ789")
    XCTAssertFalse(sut.familyCodeUnavailable)
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadData_asPlayer_familyWithoutCode_generateFails_showsUnavailableNotSpinner() async {
    mockAuthManager.setMockUser(makeUser())
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit(familyCode: nil)
    mockFamilyService.regenerateCodeError = URLError(.notConnectedToInternet)

    await sut.loadData()

    XCTAssertNil(sut.familyCode)
    XCTAssertTrue(sut.familyCodeUnavailable)
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadData_asPlayer_familyWithCode_doesNotRegenerate() async {
    mockAuthManager.setMockUser(makeUser())
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit(familyCode: "FAM-ABC123")

    await sut.loadData()

    XCTAssertEqual(mockFamilyService.regenerateCodeCallCount, 0)
    XCTAssertFalse(sut.familyCodeUnavailable)
  }
}
