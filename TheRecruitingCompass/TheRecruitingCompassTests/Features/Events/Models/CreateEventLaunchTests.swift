import XCTest
@testable import TheRecruitingCompass

final class CreateEventLaunchTests: XCTestCase {
  nonisolated deinit {}

  func test_tap_withFamilyId_presentsImmediately() {
    var sut = CreateEventLaunch()
    sut.tap(familyUnitId: "fam-1", membership: .member)
    XCTAssertEqual(sut.phase, .presenting(familyUnitId: "fam-1"))
  }

  func test_tap_whileFamilyLoading_waitsAndNeverPresentsEmptyId() {
    var sut = CreateEventLaunch()
    sut.tap(familyUnitId: "", membership: .unknown)
    XCTAssertEqual(sut.phase, .waitingForFamily)
    XCTAssertTrue(sut.isWaiting)
  }

  func test_tap_blankIdWhileMember_waitsInsteadOfPresentingBlank() {
    var sut = CreateEventLaunch()
    sut.tap(familyUnitId: "  ", membership: .member)
    XCTAssertEqual(sut.phase, .waitingForFamily)
  }

  func test_familyArrives_whileWaiting_presentsAndClearsLoading() {
    var sut = CreateEventLaunch()
    sut.tap(familyUnitId: nil, membership: .unknown)
    sut.familyChanged(familyUnitId: "fam-1", membership: .member)
    XCTAssertEqual(sut.phase, .presenting(familyUnitId: "fam-1"))
    XCTAssertFalse(sut.isWaiting)
  }

  func test_familyLoadFails_whileWaiting_clearsLoadingAndShowsRetry() {
    var sut = CreateEventLaunch()
    sut.tap(familyUnitId: nil, membership: .unknown)
    sut.familyChanged(familyUnitId: nil, membership: .failed)
    XCTAssertEqual(sut.phase, .failed)
    XCTAssertFalse(sut.isWaiting)
  }

  func test_tap_afterFailedLoad_failsWithoutPresenting() {
    var sut = CreateEventLaunch()
    sut.tap(familyUnitId: nil, membership: .failed)
    XCTAssertEqual(sut.phase, .failed)
  }

  func test_retry_afterFailure_waitsAgainThenPresentsOnSuccess() {
    var sut = CreateEventLaunch()
    sut.tap(familyUnitId: nil, membership: .failed)
    sut.retry(membership: .unknown)
    XCTAssertEqual(sut.phase, .waitingForFamily)
    sut.familyChanged(familyUnitId: "fam-1", membership: .member)
    XCTAssertEqual(sut.phase, .presenting(familyUnitId: "fam-1"))
  }

  func test_cancel_whileWaiting_clearsLoadingAndIgnoresLaterFamily() {
    var sut = CreateEventLaunch()
    sut.tap(familyUnitId: nil, membership: .unknown)
    sut.cancel()
    XCTAssertEqual(sut.phase, .idle)
    sut.familyChanged(familyUnitId: "fam-1", membership: .member)
    XCTAssertEqual(sut.phase, .idle)
  }

  func test_noFamilyAfterLoad_whileWaiting_goesIdleForGateToTakeOver() {
    var sut = CreateEventLaunch()
    sut.tap(familyUnitId: nil, membership: .unknown)
    sut.familyChanged(familyUnitId: nil, membership: .none)
    XCTAssertEqual(sut.phase, .idle)
  }

  func test_familyChange_whenIdle_doesNotPresentUnprompted() {
    var sut = CreateEventLaunch()
    sut.familyChanged(familyUnitId: "fam-1", membership: .member)
    XCTAssertEqual(sut.phase, .idle)
  }

  func test_dismiss_returnsToIdle() {
    var sut = CreateEventLaunch()
    sut.tap(familyUnitId: "fam-1", membership: .member)
    sut.dismiss()
    XCTAssertEqual(sut.phase, .idle)
  }

  func test_stillUnknownChange_keepsWaiting() {
    var sut = CreateEventLaunch()
    sut.tap(familyUnitId: nil, membership: .unknown)
    sut.familyChanged(familyUnitId: nil, membership: .unknown)
    XCTAssertEqual(sut.phase, .waitingForFamily)
  }
}
