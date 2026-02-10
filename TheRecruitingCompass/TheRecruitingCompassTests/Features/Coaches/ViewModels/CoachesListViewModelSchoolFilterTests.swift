import XCTest
@testable import TheRecruitingCompass

@MainActor
final class CoachesListViewModelSchoolFilterTests: XCTestCase {

  // MARK: - School Filter Tests

  func testFilteredCoaches_WithSchoolIdFilter_ReturnsOnlyMatchingCoaches() {
    let viewModel = CoachesListViewModel()
    viewModel.allCoaches = [
      createMockCoach(id: "1", schoolId: "school-123"),
      createMockCoach(id: "2", schoolId: "school-456"),
      createMockCoach(id: "3", schoolId: "school-123"),
      createMockCoach(id: "4", schoolId: "school-789")
    ]

    viewModel.filters.schoolId = "school-123"

    let filtered = viewModel.filteredCoaches
    XCTAssertEqual(filtered.count, 2)
    XCTAssertTrue(filtered.allSatisfy { $0.schoolId == "school-123" })
  }

  func testFilteredCoaches_WithoutSchoolIdFilter_ReturnsAllCoaches() {
    let viewModel = CoachesListViewModel()
    viewModel.allCoaches = [
      createMockCoach(id: "1", schoolId: "school-123"),
      createMockCoach(id: "2", schoolId: "school-456"),
      createMockCoach(id: "3", schoolId: "school-789")
    ]

    viewModel.filters.schoolId = nil

    let filtered = viewModel.filteredCoaches
    XCTAssertEqual(filtered.count, 3)
  }

  func testFilteredCoaches_WithSchoolIdAndRoleFilter_AppliesBothFilters() {
    let viewModel = CoachesListViewModel()
    viewModel.allCoaches = [
      createMockCoach(id: "1", schoolId: "school-123", position: "head"),
      createMockCoach(id: "2", schoolId: "school-123", position: "assistant"),
      createMockCoach(id: "3", schoolId: "school-456", position: "head"),
      createMockCoach(id: "4", schoolId: "school-123", position: "head")
    ]

    viewModel.filters.schoolId = "school-123"
    viewModel.filters.role = .head

    let filtered = viewModel.filteredCoaches
    XCTAssertEqual(filtered.count, 2)
    XCTAssertTrue(filtered.allSatisfy { $0.schoolId == "school-123" && $0.role == .head })
  }

  func testFilteredCoaches_WithSchoolIdAndSearchText_AppliesBothFilters() {
    let viewModel = CoachesListViewModel()
    viewModel.allCoaches = [
      createMockCoach(id: "1", firstName: "John", lastName: "Smith", schoolId: "school-123"),
      createMockCoach(id: "2", firstName: "Jane", lastName: "Doe", schoolId: "school-123"),
      createMockCoach(id: "3", firstName: "John", lastName: "Williams", schoolId: "school-456")
    ]

    viewModel.filters.schoolId = "school-123"
    viewModel.filters.searchText = "John"

    let filtered = viewModel.filteredCoaches
    XCTAssertEqual(filtered.count, 1)
    XCTAssertEqual(filtered.first?.firstName, "John")
    XCTAssertEqual(filtered.first?.schoolId, "school-123")
  }

  func testFilteredCoaches_WithNonMatchingSchoolId_ReturnsEmpty() {
    let viewModel = CoachesListViewModel()
    viewModel.allCoaches = [
      createMockCoach(id: "1", schoolId: "school-123"),
      createMockCoach(id: "2", schoolId: "school-456")
    ]

    viewModel.filters.schoolId = "school-999"

    let filtered = viewModel.filteredCoaches
    XCTAssertEqual(filtered.count, 0)
  }

  func testFilteredCoaches_WithSchoolIdFilter_MaintainsSortOrder() {
    let viewModel = CoachesListViewModel()
    viewModel.allCoaches = [
      createMockCoach(id: "1", firstName: "Charlie", lastName: "Davis", schoolId: "school-123"),
      createMockCoach(id: "2", firstName: "Alice", lastName: "Brown", schoolId: "school-123"),
      createMockCoach(id: "3", firstName: "Bob", lastName: "Anderson", schoolId: "school-123")
    ]

    viewModel.filters.schoolId = "school-123"
    viewModel.filters.sortBy = .name

    let filtered = viewModel.filteredCoaches

    XCTAssertEqual(filtered.count, 3)
    // Verify alphabetical order by last name
    XCTAssertEqual(filtered[0].lastName, "Anderson")
    XCTAssertEqual(filtered[1].lastName, "Brown")
    XCTAssertEqual(filtered[2].lastName, "Davis")
  }

  // MARK: - Helper Methods

  private func createMockCoach(
    id: String,
    firstName: String = "Test",
    lastName: String = "Coach",
    schoolId: String,
    position: String = "head"
  ) -> Coach {
    Coach(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: "test@example.com",
      phone: "555-1234",
      position: position,
      schoolId: schoolId,
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      privateNotes: nil,
      responsivenessScore: 0.75,
      lastContactDate: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
  }
}
