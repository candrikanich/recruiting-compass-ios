import XCTest
@testable import TheRecruitingCompass

// MARK: - Mock

final class MockFeedbackService: FeedbackManaging, @unchecked Sendable {
    var shouldThrow: Error?
    var submitCallCount = 0
    var lastSubject: FeedbackSubject?
    var lastMessage: String?

    func submit(subject: FeedbackSubject, message: String) async throws {
        submitCallCount += 1
        lastSubject = subject
        lastMessage = message
        if let error = shouldThrow {
            throw error
        }
    }
}

// MARK: - Tests

@MainActor
final class AboutViewModelTests: XCTestCase {
  nonisolated deinit {}
    var sut: AboutViewModel!
    var mockService: MockFeedbackService!

    override func setUp() {
        super.setUp()
        mockService = MockFeedbackService()
        sut = AboutViewModel(feedbackService: mockService)
    }

    override func tearDown() {
        sut = nil
        mockService = nil
        super.tearDown()
    }

    // MARK: - isFormValid

    func testIsFormValidFalseWhenMessageEmpty() {
        sut.message = ""
        XCTAssertFalse(sut.isFormValid)
    }

    func testIsFormValidFalseWhenMessageWhitespaceOnly() {
        sut.message = "   \n   "
        XCTAssertFalse(sut.isFormValid)
    }

    func testIsFormValidTrueWhenMessageHasContent() {
        sut.message = "Great app!"
        XCTAssertTrue(sut.isFormValid)
    }

    // MARK: - submit success

    func testSubmitSetsSuccessState() async {
        sut.message = "Great app!"
        sut.selectedSubject = .feature

        let task = Task { await self.sut.submit() }
        // Give the task a moment to call the service before the auto-reset sleep
        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()

        XCTAssertEqual(mockService.submitCallCount, 1)
        XCTAssertEqual(mockService.lastSubject, .feature)
        XCTAssertEqual(mockService.lastMessage, "Great app!")
        if case .success = sut.submissionState { /* pass */ } else {
            XCTFail("Expected .success, got \(sut.submissionState)")
        }
        XCTAssertEqual(sut.message, "")
        XCTAssertEqual(sut.selectedSubject, .general)
    }

    // MARK: - submit failure

    func testSubmitSetsFailureStateOnError() async {
        sut.message = "Something went wrong"
        mockService.shouldThrow = FeedbackError.serverError

        await sut.submit()

        XCTAssertEqual(mockService.submitCallCount, 1)
        if case .failure(let msg) = sut.submissionState {
            XCTAssertFalse(msg.isEmpty)
        } else {
            XCTFail("Expected .failure, got \(sut.submissionState)")
        }
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - submit guard: isLoading

    func testSubmitIsNoOpWhenAlreadyLoading() async {
        sut.message = "Hello"
        sut.isLoading = true

        await sut.submit()

        XCTAssertEqual(mockService.submitCallCount, 0)
    }

    // MARK: - submit guard: empty message

    func testSubmitIsNoOpWhenMessageEmpty() async {
        sut.message = ""

        await sut.submit()

        XCTAssertEqual(mockService.submitCallCount, 0)
    }

    // MARK: - characterCount

    func testCharacterCountMatchesMessageLength() {
        sut.message = "Hello"
        XCTAssertEqual(sut.characterCount, 5)
    }
}
