import Foundation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "SchoolsListViewModel"
)

/// Tries a simple delete, then falls back to cascade delete if the backend
/// rejects the simple path (related coaches / interactions still exist).
struct DeleteSchoolUseCase: Sendable {
  enum Outcome: Sendable {
    case simple
    case cascade(DeleteResult)
  }

  private let repository: any SchoolsRepository

  init(repository: any SchoolsRepository) {
    self.repository = repository
  }

  func execute(id: String) async throws -> Outcome {
    do {
      try await repository.deleteSchool(id: id)
      return .simple
    } catch {
      logger.warning("Simple delete failed, attempting cascade delete: \(error.localizedDescription)")
      let result = try await repository.cascadeDeleteSchool(id: id)
      return .cascade(result)
    }
  }
}
