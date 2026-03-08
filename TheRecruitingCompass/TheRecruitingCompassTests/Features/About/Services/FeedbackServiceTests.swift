import XCTest
@testable import TheRecruitingCompass

// MockFeedbackService is defined in AboutViewModelTests.swift (same test module)

@MainActor
final class FeedbackServiceTests: XCTestCase {

    // MARK: - FeedbackSubject

    func testFeedbackSubject_AllCases_HaveRawValues() {
        XCTAssertEqual(FeedbackSubject.bug.rawValue, "bug")
        XCTAssertEqual(FeedbackSubject.feature.rawValue, "feature")
        XCTAssertEqual(FeedbackSubject.question.rawValue, "question")
        XCTAssertEqual(FeedbackSubject.general.rawValue, "general")
    }

    func testFeedbackSubject_DisplayNames_AreHumanReadable() {
        XCTAssertEqual(FeedbackSubject.bug.displayName, "Bug Report")
        XCTAssertEqual(FeedbackSubject.feature.displayName, "Feature Request")
        XCTAssertEqual(FeedbackSubject.question.displayName, "Question")
        XCTAssertEqual(FeedbackSubject.general.displayName, "General Feedback")
    }

    func testFeedbackSubject_AllCases_HasFourMembers() {
        XCTAssertEqual(FeedbackSubject.allCases.count, 4)
    }

    // MARK: - FeedbackError descriptions

    func testFeedbackError_NotConfigured_HasDescription() {
        XCTAssertEqual(
            FeedbackError.notConfigured.errorDescription,
            "Feedback service is not available."
        )
    }

    func testFeedbackError_ServerError_HasDescription() {
        XCTAssertEqual(
            FeedbackError.serverError.errorDescription,
            "Failed to send feedback. Please try again."
        )
    }

    func testFeedbackError_NetworkError_HasDescription() {
        let underlying = NSError(domain: "Test", code: -1009)
        XCTAssertEqual(
            FeedbackError.networkError(underlying).errorDescription,
            "Network error. Please check your connection."
        )
    }

    // MARK: - MockFeedbackService (protocol contract)

    func testMockService_ValidSubmission_Succeeds() async throws {
        let mock = MockFeedbackService()

        try await mock.submit(subject: .bug, message: "App crashes on launch")

        XCTAssertEqual(mock.submitCallCount, 1)
        XCTAssertEqual(mock.lastSubject, .bug)
        XCTAssertEqual(mock.lastMessage, "App crashes on launch")
    }

    func testMockService_WhenShouldThrow_ThrowsConfiguredError() async {
        let mock = MockFeedbackService()
        mock.shouldThrow = FeedbackError.serverError

        do {
            try await mock.submit(subject: .general, message: "Hello")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is FeedbackError)
            XCTAssertEqual(mock.submitCallCount, 1)
        }
    }

    func testMockService_NotConfiguredError_ThrowsCorrectType() async {
        let mock = MockFeedbackService()
        mock.shouldThrow = FeedbackError.notConfigured

        do {
            try await mock.submit(subject: .feature, message: "New idea")
            XCTFail("Expected error to be thrown")
        } catch FeedbackError.notConfigured {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testMockService_NetworkError_ThrowsCorrectType() async {
        let mock = MockFeedbackService()
        let underlying = NSError(domain: "NSURLErrorDomain", code: -1009)
        mock.shouldThrow = FeedbackError.networkError(underlying)

        do {
            try await mock.submit(subject: .question, message: "How does this work?")
            XCTFail("Expected error to be thrown")
        } catch FeedbackError.networkError {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
