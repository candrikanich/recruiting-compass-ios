import XCTest
@testable import TheRecruitingCompass

final class DeleteSchoolUseCaseTests: XCTestCase {
  nonisolated deinit {}

  func testSimpleDelete_succeedsWithoutCascade() async throws {
    let repository = MockSchoolsService()
    let sut = DeleteSchoolUseCase(repository: repository)

    let outcome = try await sut.execute(id: "school-1")

    XCTAssertEqual(repository.deleteSchoolCallCount, 1)
    XCTAssertEqual(repository.cascadeDeleteSchoolCallCount, 0)
    if case .simple = outcome { } else {
      XCTFail("Expected simple delete")
    }
  }

  func testSimpleDeleteFailure_fallsBackToCascade() async throws {
    let repository = MockSchoolsService()
    repository.simpleDeleteShouldFail = true
    repository.stubbedDeleteResult = DeleteResult(isCascadeUsed: true, deletedInteractions: 3, deletedNotes: 1)
    let sut = DeleteSchoolUseCase(repository: repository)

    let outcome = try await sut.execute(id: "school-1")

    XCTAssertEqual(repository.deleteSchoolCallCount, 1)
    XCTAssertEqual(repository.cascadeDeleteSchoolCallCount, 1)
    guard case .cascade(let result) = outcome else {
      return XCTFail("Expected cascade")
    }
    XCTAssertEqual(result.deletedInteractions, 3)
    XCTAssertEqual(result.deletedNotes, 1)
  }

  func testBothDeletesFail_throws() async {
    let repository = MockSchoolsService()
    repository.shouldThrowError = true
    let sut = DeleteSchoolUseCase(repository: repository)

    do {
      _ = try await sut.execute(id: "school-1")
      XCTFail("Expected throw")
    } catch {
      XCTAssertEqual(repository.deleteSchoolCallCount, 1)
      XCTAssertEqual(repository.cascadeDeleteSchoolCallCount, 1)
    }
  }
}
