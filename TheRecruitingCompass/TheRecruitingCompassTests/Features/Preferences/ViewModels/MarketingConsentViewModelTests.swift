import XCTest
@testable import TheRecruitingCompass

@MainActor
final class MarketingConsentViewModelTests: XCTestCase {
  nonisolated deinit {}
  var sut: MarketingConsentViewModel!
  var service: MockMarketingConsentService!

  override func setUp() {
    super.setUp()
    service = MockMarketingConsentService()
    sut = MarketingConsentViewModel(service: service)
  }

  override func tearDown() {
    sut = nil
    service = nil
    super.tearDown()
  }

  func test_initialState_hidden() {
    XCTAssertFalse(sut.isEligible)
    XCTAssertFalse(sut.optIn)
  }

  func test_load_eligible_showsCurrentValue() async {
    service.fetchResult = .success(MarketingConsent(eligible: true, optIn: true, updatedAt: nil))
    await sut.load()
    XCTAssertTrue(sut.isEligible)
    XCTAssertTrue(sut.optIn)
  }

  func test_load_ineligible_staysHidden() async {
    service.fetchResult = .success(MarketingConsent(eligible: false, optIn: false, updatedAt: nil))
    await sut.load()
    XCTAssertFalse(sut.isEligible)
  }

  func test_load_failure_staysHiddenWithoutError() async {
    service.fetchResult = .failure(MarketingConsentError.server(500))
    await sut.load()
    XCTAssertFalse(sut.isEligible)
    XCTAssertNil(sut.errorMessage)
  }

  func test_setOptIn_success_persists() async {
    await sut.load()
    await sut.setOptIn(true)
    XCTAssertEqual(service.updateCalls, [true])
    XCTAssertTrue(sut.optIn)
    XCTAssertNil(sut.errorMessage)
    XCTAssertFalse(sut.isSaving)
  }

  func test_setOptIn_failure_rollsBack() async {
    await sut.load()
    service.updateResult = .failure(MarketingConsentError.server(500))
    await sut.setOptIn(true)
    XCTAssertFalse(sut.optIn)
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertFalse(sut.isSaving)
  }

  func test_setOptIn_forbidden_rollsBackAndHides() async {
    await sut.load()
    service.updateResult = .failure(MarketingConsentError.notEligible)
    await sut.setOptIn(true)
    XCTAssertFalse(sut.optIn)
    XCTAssertFalse(sut.isEligible)
  }

  func test_setOptIn_sameValue_isNoOp() async {
    await sut.load()
    await sut.setOptIn(false)
    XCTAssertTrue(service.updateCalls.isEmpty)
  }
}
