import XCTest
@testable import TheRecruitingCompass

final class LoadablePhaseTests: XCTestCase {

  func testFirstLoad_IsLoading() {
    XCTAssertEqual(
      LoadablePhase.resolve(isLoading: true, isEmpty: true),
      .loading
    )
  }

  func testRefreshWithData_StaysPopulated() {
    XCTAssertEqual(
      LoadablePhase.resolve(isLoading: true, isEmpty: false),
      .populated
    )
  }

  func testEmptyCollection_IsEmpty() {
    XCTAssertEqual(
      LoadablePhase.resolve(isLoading: false, isEmpty: true),
      .empty
    )
  }

  func testEmptyWithError_IsFailed() {
    XCTAssertEqual(
      LoadablePhase.resolve(isLoading: false, isEmpty: true, errorMessage: "Unable to load"),
      .failed("Unable to load")
    )
  }

  func testDataWithError_StaysPopulated() {
    XCTAssertEqual(
      LoadablePhase.resolve(isLoading: false, isEmpty: false, errorMessage: "Unable to load"),
      .populated
    )
  }

  func testLoadingTakesPrecedenceOverError() {
    XCTAssertEqual(
      LoadablePhase.resolve(isLoading: true, isEmpty: true, errorMessage: "Unable to load"),
      .loading
    )
  }

  func testBlankErrorMessage_TreatedAsEmpty() {
    XCTAssertEqual(
      LoadablePhase.resolve(isLoading: false, isEmpty: true, errorMessage: ""),
      .empty
    )
  }

  func testPopulated_WhenNotEmpty() {
    XCTAssertEqual(
      LoadablePhase.resolve(isLoading: false, isEmpty: false),
      .populated
    )
  }
}
