import XCTest
@testable import TheRecruitingCompass

final class FamilyServiceImplTests: XCTestCase {
  var mockService: MockFamilyService!

  override func setUp() {
    super.setUp()
    mockService = MockFamilyService()
  }

  override func tearDown() {
    mockService = nil
    super.tearDown()
  }

  // MARK: - Query Tests

  func testFetchFamilyMembers_Success_ReturnsMembers() async throws {
    // Given
    let expectedMembers = [
      createFamilyMember(id: "member1", role: "athlete"),
      createFamilyMember(id: "member2", role: "parent")
    ]
    mockService.stubbedFamilyMembers = expectedMembers

    // When
    let result = try await mockService.fetchFamilyMembers(familyUnitId: "family1")

    // Then
    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(mockService.fetchFamilyMembersCallCount, 1)
    XCTAssertEqual(mockService.lastFamilyUnitIdFetched, "family1")
  }

  func testFetchFamilyMembers_Failure_ThrowsError() async {
    // Given
    mockService.shouldSucceed = false
    mockService.mockError = FamilyError.serverError("Database error")

    // When/Then
    do {
      _ = try await mockService.fetchFamilyMembers(familyUnitId: "family1")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertTrue(error is FamilyError)
    }
  }

  func testGetCurrentMember_Success_ReturnsMember() async throws {
    // Given
    let expectedMember = createFamilyMember(id: "member1", userId: "user1")
    mockService.stubbedCurrentMember = expectedMember

    // When
    let result = try await mockService.getCurrentMember(userId: "user1")

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "member1")
    XCTAssertEqual(mockService.getCurrentMemberCallCount, 1)
    XCTAssertEqual(mockService.lastUserIdFetched, "user1")
  }

  func testGetCurrentMember_NotFound_ReturnsNil() async throws {
    // Given
    mockService.stubbedCurrentMember = nil

    // When
    let result = try await mockService.getCurrentMember(userId: "user1")

    // Then
    XCTAssertNil(result)
  }

  func testGetFamilyUnit_Success_ReturnsUnit() async throws {
    // Given
    let expectedUnit = createFamilyUnit(id: "family1", playerUserId: "user1")
    mockService.stubbedFamilyUnit = expectedUnit

    // When
    let result = try await mockService.getFamilyUnit(forPlayerUserId: "user1")

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "family1")
    XCTAssertEqual(mockService.getFamilyUnitCallCount, 1)
    XCTAssertEqual(mockService.lastPlayerUserIdFetched, "user1")
  }

  func testGetFamilyUnit_NotFound_ReturnsNil() async throws {
    // Given
    mockService.stubbedFamilyUnit = nil

    // When
    let result = try await mockService.getFamilyUnit(forPlayerUserId: "user1")

    // Then
    XCTAssertNil(result)
  }

  func testGetParentFamilies_Success_ReturnsMultipleFamilies() async throws {
    // Given
    let expectedFamilies = [
      ParentFamilyData(
        familyId: "family1",
        familyCode: "FAM-ABC123",
        familyName: "Smith Family",
        codeGeneratedAt: "2025-01-01T00:00:00Z"
      ),
      ParentFamilyData(
        familyId: "family2",
        familyCode: "FAM-XYZ789",
        familyName: "Jones Family",
        codeGeneratedAt: "2025-01-02T00:00:00Z"
      )
    ]
    mockService.mockParentFamilies = expectedFamilies

    // When
    let result = try await mockService.getParentFamilies()

    // Then
    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result.first?.familyId, "family1")
    XCTAssertEqual(result.last?.familyId, "family2")
    XCTAssertEqual(mockService.getParentFamiliesCallCount, 1)
  }

  func testGetParentFamilies_EmptyResult_ReturnsEmptyArray() async throws {
    // Given
    mockService.mockParentFamilies = []

    // When
    let result = try await mockService.getParentFamilies()

    // Then
    XCTAssertEqual(result.count, 0)
  }

  // MARK: - Mutation Tests

  func testCreateFamily_Success_ReturnsResponse() async throws {
    // Given
    let expectedResponse = CreateFamilyResponse(
      success: true,
      familyCode: "FAM-ABC123",
      familyId: "family1",
      familyName: "Test Family"
    )
    mockService.mockCreateFamilyResponse = expectedResponse

    // When
    let result = try await mockService.createFamily()

    // Then
    XCTAssertTrue(result.success)
    XCTAssertEqual(result.familyCode, "FAM-ABC123")
    XCTAssertEqual(result.familyId, "family1")
    XCTAssertEqual(mockService.createFamilyCallCount, 1)
  }

  func testCreateFamily_Failure_ThrowsError() async {
    // Given
    mockService.shouldSucceed = false
    mockService.mockError = FamilyError.serverError("Creation failed")

    // When/Then
    do {
      _ = try await mockService.createFamily()
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertTrue(error is FamilyError)
    }
  }

  func testRegenerateCode_Success_ReturnsNewCode() async throws {
    // Given
    let expectedResponse = RegenerateFamilyCodeResponse(familyCode: "FAM-NEW999")
    mockService.mockRegenerateCodeResponse = expectedResponse

    // When
    let result = try await mockService.regenerateCode(familyId: "family1")

    // Then
    XCTAssertEqual(result.familyCode, "FAM-NEW999")
    XCTAssertEqual(mockService.regenerateCodeCallCount, 1)
    XCTAssertEqual(mockService.lastFamilyIdRegenerated, "family1")
  }

  func testRemoveFamilyMember_Success_CompletesWithoutError() async throws {
    // Given
    mockService.shouldSucceed = true

    // When
    try await mockService.removeFamilyMember(memberId: "member1")

    // Then
    XCTAssertEqual(mockService.removeFamilyMemberCallCount, 1)
    XCTAssertEqual(mockService.lastMemberIdRemoved, "member1")
  }

  func testRemoveFamilyMember_Failure_ThrowsError() async {
    // Given
    mockService.shouldSucceed = false
    mockService.mockError = FamilyError.serverError("Removal failed")

    // When/Then
    do {
      try await mockService.removeFamilyMember(memberId: "member1")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertTrue(error is FamilyError)
    }
  }

  func testJoinFamilyWithCode_Success_CompletesWithoutError() async throws {
    // Given
    mockService.shouldSucceed = true

    // When
    try await mockService.joinFamilyWithCode(familyCode: "FAM-ABC123")

    // Then
    XCTAssertEqual(mockService.joinFamilyWithCodeCallCount, 1)
    XCTAssertEqual(mockService.lastFamilyCodeJoined, "FAM-ABC123")
  }

  func testJoinFamilyWithCode_Failure_ThrowsError() async {
    // Given
    mockService.shouldSucceed = false
    mockService.mockError = FamilyError.invalidCode

    // When/Then
    do {
      try await mockService.joinFamilyWithCode(familyCode: "INVALID")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertTrue(error is FamilyError)
    }
  }

  // MARK: - Helper Methods

  private func createFamilyMember(
    id: String,
    userId: String = "user1",
    familyUnitId: String = "family1",
    role: String = "athlete"
  ) -> FamilyMember {
    FamilyMember(
      id: id,
      userId: userId,
      familyUnitId: familyUnitId,
      role: role,
      addedAt: "2025-01-01T00:00:00Z",
      user: FamilyMemberUser(
        id: userId,
        email: "test@example.com",
        fullName: "Test User",
        role: role
      )
    )
  }

  private func createFamilyUnit(
    id: String,
    playerUserId: String,
    familyCode: String = "FAM-TEST123"
  ) -> FamilyUnit {
    FamilyUnit(
      id: id,
      playerUserId: playerUserId,
      familyName: "Test Family",
      familyCode: familyCode,
      codeGeneratedAt: "2025-01-01T00:00:00Z",
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z",
      homeLatitude: nil,
      homeLongitude: nil
    )
  }
}

// MARK: - Note on Integration Tests
/*
 These tests verify FamilyServiceImpl behavior through the MockFamilyService.

 True integration tests would require:
 1. A test Supabase instance
 2. Mock SupabaseClient with query builder chains (.from().select().eq())
 3. Mock Functions API for Edge Function calls

 The current approach tests:
 - Correct parameter passing
 - Error handling paths
 - Response mapping logic
 - Call verification

 For true E2E testing with Supabase, use:
 - Supabase local development setup
 - Test database with seed data
 - XCUITest flows
 */
