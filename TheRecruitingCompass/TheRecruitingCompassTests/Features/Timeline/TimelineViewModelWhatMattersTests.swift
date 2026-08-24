import XCTest
@testable import TheRecruitingCompass

@MainActor
final class TimelineViewModelWhatMattersTests: XCTestCase {
  nonisolated deinit {}

  func testLoad_keepsTopFiveWhatMattersItems() async {
    let mockTasksService = MockTasksService()
    let mockAPIService = MockTimelineAPIService()
    let mockPreferenceManager = MockPreferenceManager()
    let mockAuthManager = MockAuthManager()
    mockAuthManager.setMockUser(userMock(id: "solo-user-1"))
    let familyManager = FamilyManager(familyService: MockFamilyService(), authManager: mockAuthManager)

    mockAPIService.stubbedWhatMatters = (1...7).map {
      WhatMattersItem(
        taskId: "t\($0)",
        title: "T\($0)",
        whyItMatters: "why",
        category: "recruiting",
        priority: 10 - $0,
        isRequired: true
      )
    }

    let viewModel = TimelineViewModel(
      tasksService: mockTasksService,
      apiService: mockAPIService,
      preferenceService: mockPreferenceManager,
      authManager: mockAuthManager,
      familyManager: familyManager
    )

    await viewModel.load()

    XCTAssertEqual(viewModel.whatMattersItems.count, 5)
    XCTAssertEqual(viewModel.whatMattersItems.map(\.taskId), ["t1", "t2", "t3", "t4", "t5"])
    XCTAssertEqual(viewModel.currentTask?.taskId, "t1")
  }

  private func userMock(id: String) -> User {
    User(
      id: id,
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      role: .player
    )
  }
}
