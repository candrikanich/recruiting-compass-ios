import Foundation

protocol FamilyManaging: Sendable {
  // Existing methods
  func fetchFamilyMembers(familyUnitId: String) async throws -> [FamilyMember]
  func getCurrentMember(userId: String) async throws -> FamilyMember?
  func getFamilyUnit(forPlayerUserId userId: String) async throws -> FamilyUnit?

  // Family Management methods (Player)
  func createFamily() async throws -> CreateFamilyResponse
  func regenerateCode(familyId: String) async throws -> RegenerateFamilyCodeResponse
  func removeFamilyMember(memberId: String) async throws

  // Family Management methods (Parent)
  func joinFamilyWithCode(familyCode: String) async throws
  func getParentFamilies() async throws -> [ParentFamilyData]
}

