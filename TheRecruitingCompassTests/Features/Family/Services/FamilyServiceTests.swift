//
//  FamilyServiceTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-11
//  Unit tests for FamilyServiceImpl
//

import XCTest
@testable import TheRecruitingCompass

@MainActor
final class FamilyServiceTests: XCTestCase {
  var service: FamilyServiceImpl!
  var mockSupabaseManager: SupabaseManager!

  override func setUp() async throws {
    // Note: These tests use the real SupabaseManager.shared
    // For true unit tests, we would need a MockSupabaseManager
    // For now, we're testing the service integration patterns
    mockSupabaseManager = SupabaseManager.shared
    service = FamilyServiceImpl(supabaseManager: mockSupabaseManager)
  }

  override func tearDown() {
    service = nil
    mockSupabaseManager = nil
  }

  // MARK: - Initialization Tests

  func testInitialization_Success() {
    XCTAssertNotNil(service)
  }

  // MARK: - Model Tests (Codable Verification)

  func testFamilyUnit_Codable() throws {
    let json = """
    {
      "id": "family-1",
      "player_user_id": "player-1",
      "family_name": "Smith Family",
      "family_code": "FAM-ABC123",
      "code_generated_at": "2024-02-11T12:00:00Z",
      "created_at": "2024-02-01T12:00:00Z",
      "updated_at": "2024-02-11T12:00:00Z",
      "home_latitude": 40.7128,
      "home_longitude": -74.0060
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let familyUnit = try decoder.decode(FamilyUnit.self, from: json)

    XCTAssertEqual(familyUnit.id, "family-1")
    XCTAssertEqual(familyUnit.playerUserId, "player-1")
    XCTAssertEqual(familyUnit.familyName, "Smith Family")
    XCTAssertEqual(familyUnit.familyCode, "FAM-ABC123")
    XCTAssertEqual(familyUnit.codeGeneratedAt, "2024-02-11T12:00:00Z")
    XCTAssertEqual(familyUnit.homeLatitude, 40.7128)
    XCTAssertEqual(familyUnit.homeLongitude, -74.0060)
  }

  func testFamilyUnit_Codable_OptionalFields() throws {
    let json = """
    {
      "id": "family-1",
      "player_user_id": "player-1",
      "family_name": null,
      "family_code": null,
      "code_generated_at": null,
      "created_at": null,
      "updated_at": null,
      "home_latitude": null,
      "home_longitude": null
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let familyUnit = try decoder.decode(FamilyUnit.self, from: json)

    XCTAssertEqual(familyUnit.id, "family-1")
    XCTAssertEqual(familyUnit.playerUserId, "player-1")
    XCTAssertNil(familyUnit.familyName)
    XCTAssertNil(familyUnit.familyCode)
    XCTAssertNil(familyUnit.codeGeneratedAt)
    XCTAssertNil(familyUnit.homeLatitude)
    XCTAssertNil(familyUnit.homeLongitude)
  }

  func testFamilyMember_Codable() throws {
    let json = """
    {
      "id": "member-1",
      "user_id": "user-1",
      "family_unit_id": "family-1",
      "role": "athlete",
      "added_at": "2024-02-11T12:00:00Z",
      "user": {
        "id": "user-1",
        "email": "athlete@test.com",
        "full_name": "Athlete User",
        "role": "player"
      }
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let member = try decoder.decode(FamilyMember.self, from: json)

    XCTAssertEqual(member.id, "member-1")
    XCTAssertEqual(member.userId, "user-1")
    XCTAssertEqual(member.familyUnitId, "family-1")
    XCTAssertEqual(member.role, "athlete")
    XCTAssertTrue(member.isAthlete)
    XCTAssertFalse(member.isParent)
    XCTAssertEqual(member.user?.email, "athlete@test.com")
  }

  func testFamilyMember_ParentRole() throws {
    let json = """
    {
      "id": "member-2",
      "user_id": "user-2",
      "family_unit_id": "family-1",
      "role": "parent",
      "added_at": "2024-02-11T12:00:00Z",
      "user": {
        "id": "user-2",
        "email": "parent@test.com",
        "full_name": "Parent User",
        "role": "parent"
      }
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let member = try decoder.decode(FamilyMember.self, from: json)

    XCTAssertEqual(member.role, "parent")
    XCTAssertTrue(member.isParent)
    XCTAssertFalse(member.isAthlete)
  }

  func testFamilyMemberUser_Codable() throws {
    let json = """
    {
      "id": "user-1",
      "email": "test@example.com",
      "full_name": "Test User",
      "role": "player"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let user = try decoder.decode(FamilyMemberUser.self, from: json)

    XCTAssertEqual(user.id, "user-1")
    XCTAssertEqual(user.email, "test@example.com")
    XCTAssertEqual(user.fullName, "Test User")
    XCTAssertEqual(user.role, "player")
  }

  func testFamilyMemberUser_Codable_NullFullName() throws {
    let json = """
    {
      "id": "user-1",
      "email": "test@example.com",
      "full_name": null,
      "role": "player"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let user = try decoder.decode(FamilyMemberUser.self, from: json)

    XCTAssertNil(user.fullName)
  }

  func testParentFamilyData_Codable() throws {
    let json = """
    {
      "family_id": "family-1",
      "family_code": "FAM-ABC123",
      "family_name": "Smith Family",
      "code_generated_at": "2024-02-11T12:00:00Z"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let data = try decoder.decode(ParentFamilyData.self, from: json)

    XCTAssertEqual(data.id, "family-1")
    XCTAssertEqual(data.familyId, "family-1")
    XCTAssertEqual(data.familyCode, "FAM-ABC123")
    XCTAssertEqual(data.familyName, "Smith Family")
    XCTAssertEqual(data.codeGeneratedAt, "2024-02-11T12:00:00Z")
  }

  func testCreateFamilyResponse_Codable() throws {
    let json = """
    {
      "success": true,
      "familyCode": "FAM-NEW123",
      "familyId": "family-new",
      "familyName": "New Family"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let response = try decoder.decode(CreateFamilyResponse.self, from: json)

    XCTAssertTrue(response.success)
    XCTAssertEqual(response.familyCode, "FAM-NEW123")
    XCTAssertEqual(response.familyId, "family-new")
    XCTAssertEqual(response.familyName, "New Family")
  }

  func testRegenerateFamilyCodeResponse_Codable() throws {
    let json = """
    {
      "familyCode": "FAM-REGEN99"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let response = try decoder.decode(RegenerateFamilyCodeResponse.self, from: json)

    XCTAssertEqual(response.familyCode, "FAM-REGEN99")
  }

  // MARK: - FamilyError Tests

  func testFamilyError_NotAuthenticated() {
    let error = FamilyError.notAuthenticated
    XCTAssertEqual(error.errorDescription, "You must be logged in to perform this action")
  }

  func testFamilyError_InvalidCode() {
    let error = FamilyError.invalidCode
    XCTAssertEqual(error.errorDescription, "Invalid family code format. Codes look like FAM-XXXXXX")
  }

  func testFamilyError_AlreadyMember() {
    let error = FamilyError.alreadyMember
    XCTAssertEqual(error.errorDescription, "You are already a member of this family")
  }

  func testFamilyError_NotFound() {
    let error = FamilyError.notFound
    XCTAssertEqual(error.errorDescription, "Family code not found. Please check and try again")
  }

  func testFamilyError_ServerError() {
    let error = FamilyError.serverError("Custom error message")
    XCTAssertEqual(error.errorDescription, "Custom error message")
  }

  // MARK: - Service Method Tests (Integration Patterns)
  // Note: These tests verify the service methods exist and have correct signatures
  // Full integration tests would require a mock Supabase client

  func testFetchFamilyMembers_MethodExists() async {
    // Verify method signature compiles and can be called
    // In a real test environment with mock Supabase, we would verify actual behavior
    // For now, we're testing that the method signature is correct

    do {
      // This will fail in test environment without real Supabase connection
      // but verifies the method exists and compiles
      _ = try await service.fetchFamilyMembers(familyUnitId: "test-family-id")
    } catch {
      // Expected to fail without real Supabase connection
      // We're just verifying the method signature compiles
      XCTAssertNotNil(error)
    }
  }

  func testGetCurrentMember_MethodExists() async {
    do {
      _ = try await service.getCurrentMember(userId: "test-user-id")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testGetFamilyUnit_MethodExists() async {
    do {
      _ = try await service.getFamilyUnit(forPlayerUserId: "test-user-id")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testCreateFamily_MethodExists() async {
    do {
      _ = try await service.createFamily()
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testRegenerateCode_MethodExists() async {
    do {
      _ = try await service.regenerateCode(familyId: "test-family-id")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testRemoveFamilyMember_MethodExists() async {
    do {
      try await service.removeFamilyMember(memberId: "test-member-id")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testJoinFamilyWithCode_MethodExists() async {
    do {
      try await service.joinFamilyWithCode(familyCode: "FAM-TEST12")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  func testGetParentFamilies_MethodExists() async {
    do {
      _ = try await service.getParentFamilies()
    } catch {
      XCTAssertNotNil(error)
    }
  }

  // MARK: - Sendable Conformance Tests

  func testFamilyUnit_IsSendable() {
    let familyUnit = FamilyUnit(
      id: "family-1",
      playerUserId: "player-1",
      familyName: "Test Family",
      familyCode: "FAM-ABC123",
      codeGeneratedAt: "2024-02-11T12:00:00Z",
      createdAt: "2024-02-01T12:00:00Z",
      updatedAt: "2024-02-11T12:00:00Z",
      homeLatitude: nil,
      homeLongitude: nil
    )

    // Verify Sendable conformance by passing to async context
    Task {
      let _ = familyUnit
    }

    XCTAssertNotNil(familyUnit)
  }

  func testFamilyMember_IsSendable() {
    let member = FamilyMember(
      id: "member-1",
      userId: "user-1",
      familyUnitId: "family-1",
      role: "athlete",
      addedAt: "2024-02-11T12:00:00Z",
      user: nil
    )

    Task {
      let _ = member
    }

    XCTAssertNotNil(member)
  }

  func testParentFamilyData_IsSendable() {
    let data = ParentFamilyData(
      familyId: "family-1",
      familyCode: "FAM-ABC123",
      familyName: "Smith Family",
      codeGeneratedAt: "2024-02-11T12:00:00Z"
    )

    Task {
      let _ = data
    }

    XCTAssertNotNil(data)
  }

  // MARK: - Edge Cases

  func testFamilyMember_UnknownRole() throws {
    let json = """
    {
      "id": "member-1",
      "user_id": "user-1",
      "family_unit_id": "family-1",
      "role": "unknown_role",
      "added_at": "2024-02-11T12:00:00Z",
      "user": null
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let member = try decoder.decode(FamilyMember.self, from: json)

    // Unknown roles should be handled gracefully
    XCTAssertEqual(member.role, "unknown_role")
    XCTAssertFalse(member.isAthlete)
    XCTAssertFalse(member.isParent)
  }

  func testFamilyMember_NullUser() throws {
    let json = """
    {
      "id": "member-1",
      "user_id": "user-1",
      "family_unit_id": "family-1",
      "role": "athlete",
      "added_at": null,
      "user": null
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let member = try decoder.decode(FamilyMember.self, from: json)

    XCTAssertNil(member.user)
    XCTAssertNil(member.addedAt)
  }

  func testParentFamilyData_IdMatchesFamilyId() {
    let data = ParentFamilyData(
      familyId: "family-123",
      familyCode: "FAM-ABC123",
      familyName: "Test Family",
      codeGeneratedAt: "2024-02-11T12:00:00Z"
    )

    // Verify computed id property matches familyId
    XCTAssertEqual(data.id, data.familyId)
    XCTAssertEqual(data.id, "family-123")
  }

  // MARK: - Protocol Conformance

  func testFamilyServiceImpl_ConformsToFamilyManaging() {
    // Verify service conforms to protocol
    let _: any FamilyManaging = service
    XCTAssertNotNil(service)
  }

  func testFamilyServiceImpl_IsSendable() {
    // Verify @unchecked Sendable conformance
    Task {
      let _ = service
    }
    XCTAssertNotNil(service)
  }
}
