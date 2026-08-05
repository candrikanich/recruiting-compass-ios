import XCTest
@testable import TheRecruitingCompass

@MainActor
final class HelpFeedbackViewModelTests: XCTestCase {
  nonisolated deinit {}

  var viewModel: HelpFeedbackViewModel!
  var mockService: MockHelpFeedbackService!
  var mockAuthManager: MockAuthManager!

  override func setUp() {
    mockService = MockHelpFeedbackService()
    mockAuthManager = MockAuthManager()
    mockAuthManager.setMockUser(userMock())
    viewModel = HelpFeedbackViewModel(
      page: "getting-started",
      feedbackService: mockService,
      authManager: mockAuthManager
    )
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
    mockAuthManager = nil
  }

  func testSubmit_noUser_isNoOp() async {
    mockAuthManager.user = nil

    await viewModel.submit(helpful: true)

    XCTAssertEqual(mockService.submitFeedbackCallCount, 0)
    XCTAssertFalse(viewModel.submitted)
  }

  func testSubmit_success_setsSubmittedTrue() async {
    await viewModel.submit(helpful: true)

    XCTAssertEqual(mockService.submitFeedbackCallCount, 1)
    XCTAssertEqual(mockService.lastPage, "getting-started")
    XCTAssertEqual(mockService.lastHelpful, true)
    XCTAssertEqual(mockService.lastUserId, "user-1")
    XCTAssertTrue(viewModel.submitted)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testSubmit_notHelpful_passesFalseThrough() async {
    await viewModel.submit(helpful: false)
    XCTAssertEqual(mockService.lastHelpful, false)
  }

  func testSubmit_serviceThrows_setsErrorMessage() async {
    mockService.shouldThrowOnSubmit = true

    await viewModel.submit(helpful: true)

    XCTAssertEqual(viewModel.errorMessage, "Couldn't send feedback. Please try again.")
    XCTAssertFalse(viewModel.submitted)
  }

  // MARK: - Helpers

  private func userMock() -> User {
    User(
      id: "user-1",
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      role: .player
    )
  }
}
