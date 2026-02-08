import Foundation

protocol FamilyManaging: Sendable {
  func fetchFamilyMembers(familyUnitId: String) async throws -> [FamilyMember]
  func getCurrentMember(userId: String) async throws -> FamilyMember?
}
