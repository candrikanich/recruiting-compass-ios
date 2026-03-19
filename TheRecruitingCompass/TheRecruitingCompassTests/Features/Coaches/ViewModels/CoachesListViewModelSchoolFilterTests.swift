import XCTest
@testable import TheRecruitingCompass

@MainActor
final class CoachesListViewModelSchoolFilterTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - School Filter Tests

  func testFilteredCoaches_WithSchoolIdFilter_ReturnsOnlyMatchingCoaches() async {
    let mockService = MockCoachesService()
    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: nil,
      authManager: nil
    )

    viewModel.allCoaches = [
      createMockCoach(id: "1", schoolId: "school-123"),
      createMockCoach(id: "2", schoolId: "school-456"),
      createMockCoach(id: "3", schoolId: "school-123"),
      createMockCoach(id: "4", schoolId: "school-789")
    ]

    viewModel.filters.schoolId = "school-123"

    let filtered = viewModel.filteredCoaches
    XCTAssertEqual(filtered.count, 2, "Should return 2 coaches from school-123")
    XCTAssertTrue(filtered.allSatisfy { $0.schoolId == "school-123" }, "All filtered coaches should be from school-123")
  }

  func testFilteredCoaches_WithoutSchoolIdFilter_ReturnsAllCoaches() async {
    let mockService = MockCoachesService()
    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: nil,
      authManager: nil
    )

    viewModel.allCoaches = [
      createMockCoach(id: "1", schoolId: "school-123"),
      createMockCoach(id: "2", schoolId: "school-456"),
      createMockCoach(id: "3", schoolId: "school-789")
    ]

    viewModel.filters.schoolId = nil

    let filtered = viewModel.filteredCoaches
    XCTAssertEqual(filtered.count, 3, "Should return all 3 coaches when no school filter is applied")
  }

  func testFilteredCoaches_WithSchoolIdAndRoleFilter_AppliesBothFilters() async {
    let mockService = MockCoachesService()
    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: nil,
      authManager: nil
    )

    viewModel.allCoaches = [
      createMockCoach(id: "1", schoolId: "school-123", position: "head"),
      createMockCoach(id: "2", schoolId: "school-123", position: "assistant"),
      createMockCoach(id: "3", schoolId: "school-456", position: "head"),
      createMockCoach(id: "4", schoolId: "school-123", position: "head")
    ]

    viewModel.filters.schoolId = "school-123"
    viewModel.filters.role = .head

    let filtered = viewModel.filteredCoaches
    XCTAssertEqual(filtered.count, 2, "Should return 2 head coaches from school-123")
    XCTAssertTrue(
      filtered.allSatisfy { $0.schoolId == "school-123" && $0.role == .head },
      "All filtered coaches should be head coaches from school-123"
    )
  }

  func testFilteredCoaches_WithSchoolIdAndSearchText_AppliesBothFilters() async {
    let mockService = MockCoachesService()
    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: nil,
      authManager: nil
    )

    viewModel.allCoaches = [
      createMockCoach(id: "1", firstName: "John", lastName: "Smith", schoolId: "school-123"),
      createMockCoach(id: "2", firstName: "Jane", lastName: "Doe", schoolId: "school-123"),
      createMockCoach(id: "3", firstName: "John", lastName: "Williams", schoolId: "school-456")
    ]

    viewModel.filters.schoolId = "school-123"
    viewModel.filters.searchText = "John"

    let filtered = viewModel.filteredCoaches
    XCTAssertEqual(filtered.count, 1, "Should return 1 coach named John from school-123")
    XCTAssertEqual(filtered.first?.firstName, "John", "Filtered coach should be named John")
    XCTAssertEqual(filtered.first?.schoolId, "school-123", "Filtered coach should be from school-123")
  }

  func testFilteredCoaches_WithNonMatchingSchoolId_ReturnsEmpty() async {
    let mockService = MockCoachesService()
    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: nil,
      authManager: nil
    )

    viewModel.allCoaches = [
      createMockCoach(id: "1", schoolId: "school-123"),
      createMockCoach(id: "2", schoolId: "school-456")
    ]

    viewModel.filters.schoolId = "school-999"

    let filtered = viewModel.filteredCoaches
    XCTAssertEqual(filtered.count, 0, "Should return 0 coaches when filtering by non-existent school")
  }

  func testFilteredCoaches_WithSchoolIdFilter_MaintainsSortOrder() async {
    let mockService = MockCoachesService()
    let viewModel = CoachesListViewModel(
      coachesService: mockService,
      familyManager: nil,
      authManager: nil
    )

    viewModel.allCoaches = [
      createMockCoach(id: "1", firstName: "Charlie", lastName: "Davis", schoolId: "school-123"),
      createMockCoach(id: "2", firstName: "Alice", lastName: "Brown", schoolId: "school-123"),
      createMockCoach(id: "3", firstName: "Bob", lastName: "Anderson", schoolId: "school-123")
    ]

    viewModel.filters.schoolId = "school-123"
    viewModel.filters.sortBy = .name

    let filtered = viewModel.filteredCoaches

    XCTAssertEqual(filtered.count, 3, "Should return all 3 coaches from school-123")
    // Verify alphabetical order by last name
    XCTAssertEqual(filtered[0].lastName, "Anderson", "First coach should be Anderson")
    XCTAssertEqual(filtered[1].lastName, "Brown", "Second coach should be Brown")
    XCTAssertEqual(filtered[2].lastName, "Davis", "Third coach should be Davis")
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
      lastContactDate: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
  }
}
