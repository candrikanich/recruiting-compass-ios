import XCTest
import OSLog
@testable import TheRecruitingCompass

@MainActor
final class ViewModelHelpersTests: XCTestCase {
  nonisolated deinit {}

  private let logger = Logger(
    subsystem: "com.chrisandrikanich.TheRecruitingCompass",
    category: "ViewModelHelpersTests"
  )

  func testRunLoad_ClearsErrorAndLoading_OnSuccess() async {
    var isLoading = false
    var errorMessage: String? = "stale"
    var sawLoadingTrue = false

    await ViewModelHelpers.runLoad(
      setLoading: {
        isLoading = $0
        if $0 { sawLoadingTrue = true }
      },
      setError: { errorMessage = $0 },
      userMessage: "Failed",
      logger: logger
    ) {
      XCTAssertTrue(isLoading)
    }

    XCTAssertTrue(sawLoadingTrue)
    XCTAssertFalse(isLoading)
    XCTAssertNil(errorMessage)
  }

  func testRunLoad_SetsUserMessage_OnFailure() async {
    struct Boom: Error {}
    var isLoading = false
    var errorMessage: String?

    await ViewModelHelpers.runLoad(
      setLoading: { isLoading = $0 },
      setError: { errorMessage = $0 },
      userMessage: "Failed to load coaches. Please try again.",
      logger: logger
    ) {
      throw Boom()
    }

    XCTAssertFalse(isLoading)
    XCTAssertEqual(errorMessage, "Failed to load coaches. Please try again.")
  }
}
