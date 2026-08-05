import Foundation
@testable import TheRecruitingCompass

final class MockInteractionsService: InteractionsManaging, @unchecked Sendable {
  var shouldSucceed = true
  var simpleDeleteShouldFail = false
  var mockInteractions: [Interaction] = []
  var mockSchools: [School] = []
  var mockCoaches: [Coach] = []
  var mockCreatedInteraction: Interaction?
  var mockCreatedCoach: Coach?
  var deleteCallCount = 0
  var cascadeDeleteCallCount = 0
  var createInteractionCallCount = 0
  var createCoachCallCount = 0
  var fetchInteractionsCallCount = 0
  var fetchInteractionsForUserCallCount = 0
  var lastDeletedId: String?
  var lastCascadeDeletedId: String?
  var lastCreatedInteractionRequest: InteractionCreateRequest?
  var lastCreatedCoachRequest: CoachCreateRequest?

  func fetchInteractions(familyUnitId: String) async throws -> [Interaction] {
    fetchInteractionsCallCount += 1
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    return mockInteractions
  }

  func fetchInteractionsForUser(userId: String) async throws -> [Interaction] {
    fetchInteractionsForUserCallCount += 1
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    return mockInteractions.filter { $0.loggedBy == userId }
  }

  func fetchInteraction(id: String) async throws -> Interaction {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    guard let interaction = mockInteractions.first(where: { $0.id == id }) else {
      throw NSError(domain: "test", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not found"])
    }
    return interaction
  }

  func fetchLoggedByUserName(userId: String) async throws -> String {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    return "Test User"
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    return mockSchools
  }

  func fetchCoaches(familyUnitId: String) async throws -> [Coach] {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    return mockCoaches
  }

  func createInteraction(_ interaction: InteractionCreateRequest) async throws -> Interaction {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    createInteractionCallCount += 1
    lastCreatedInteractionRequest = interaction

    if let mock = mockCreatedInteraction {
      return mock
    }

    // Create default interaction
    return Interaction(
      id: UUID().uuidString,
      type: InteractionType(rawValue: interaction.type) ?? .email,
      direction: Direction(rawValue: interaction.direction) ?? .outbound,
      schoolId: interaction.schoolId,
      coachId: interaction.coachId,
      subject: interaction.subject,
      content: interaction.content,
      sentiment: interaction.sentiment.flatMap { Sentiment(rawValue: $0) },
      occurredAt: interaction.occurredAt,
      loggedBy: interaction.loggedBy,
      attachments: nil,
      familyUnitId: interaction.familyUnitId,
      createdAt: ISO8601DateFormatter().string(from: Date()),
      updatedAt: nil
    )
  }

  func createCoach(_ coach: CoachCreateRequest) async throws -> Coach {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    createCoachCallCount += 1
    lastCreatedCoachRequest = coach

    if let mock = mockCreatedCoach {
      return mock
    }

    // Create default coach
    return Coach(
      id: UUID().uuidString,
      firstName: coach.firstName,
      lastName: coach.lastName,
      email: coach.email,
      phone: coach.phone,
      position: coach.role,
      schoolId: coach.schoolId,
      twitterHandle: coach.twitterHandle,
      instagramHandle: coach.instagramHandle,
      notes: coach.notes,
      lastContactDate: nil,
      createdAt: ISO8601DateFormatter().string(from: Date()),
      updatedAt: ""
    )
  }

  func uploadAttachment(interactionId: String, fileName: String, fileData: Data) async throws -> String {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    return "https://test.url/\(fileName)"
  }

  func deleteInteraction(id: String) async throws {
    deleteCallCount += 1
    lastDeletedId = id
    if simpleDeleteShouldFail || !shouldSucceed {
      throw NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "violates foreign key constraint"])
    }
    mockInteractions.removeAll { $0.id == id }
  }

  func cascadeDeleteInteraction(id: String) async throws -> CascadeDeleteResult {
    cascadeDeleteCallCount += 1
    lastCascadeDeletedId = id
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    mockInteractions.removeAll { $0.id == id }
    return CascadeDeleteResult(deletedInteractions: 1, deletedNotes: 2)
  }

  func reset() {
    shouldSucceed = true
    simpleDeleteShouldFail = false
    mockInteractions = []
    mockSchools = []
    mockCoaches = []
    mockCreatedInteraction = nil
    mockCreatedCoach = nil
    deleteCallCount = 0
    cascadeDeleteCallCount = 0
    createInteractionCallCount = 0
    createCoachCallCount = 0
    fetchInteractionsCallCount = 0
    fetchInteractionsForUserCallCount = 0
    lastDeletedId = nil
    lastCascadeDeletedId = nil
    lastCreatedInteractionRequest = nil
    lastCreatedCoachRequest = nil
  }
}
