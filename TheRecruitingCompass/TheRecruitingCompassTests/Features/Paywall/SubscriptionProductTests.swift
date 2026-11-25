import XCTest
@testable import TheRecruitingCompass

final class SubscriptionProductTests: XCTestCase {
  func test_parsesEveryLaunchAndFutureProductId() {
    for kind in ["players", "addl"] {
      let top = kind == "players" ? 4 : 3
      for seats in 1...top {
        for period in ["annual", "monthly"] {
          let product = SubscriptionProduct(productId: "trc_\(kind)_\(seats)_\(period)")
          XCTAssertEqual(product?.seats, seats)
          XCTAssertEqual(product?.kind.rawValue, kind)
          XCTAssertEqual(product?.period.rawValue, period)
        }
      }
    }
  }

  func test_rejectsIdsThatAreNotOurTiers() {
    let strays = [
      "trc_players_5_annual", "trc_players_0_annual", "trc_addl_4_monthly", "trc_players_01_annual",
      "trc_players_1_weekly", "TRC_players_1_annual", "pro_monthly", "trc_players_1", "trc_players__annual",
      "trc_players_1_annual_extra", "", "trc_players_-1_annual"
    ]
    for id in strays { XCTAssertNil(SubscriptionProduct(productId: id), id) }
  }

  func test_tierTitles() {
    XCTAssertEqual(SubscriptionProduct(productId: "trc_players_1_annual")?.tierTitle, "1 player")
    XCTAssertEqual(SubscriptionProduct(productId: "trc_players_2_annual")?.tierTitle, "2 players")
    XCTAssertEqual(SubscriptionProduct(productId: "trc_players_4_annual")?.tierTitle, "4 or more players")
    XCTAssertEqual(SubscriptionProduct(productId: "trc_addl_1_monthly")?.tierTitle, "1 additional player")
    XCTAssertEqual(
      SubscriptionProduct(productId: "trc_addl_3_monthly")?.tierTitle, "3 or more additional players"
    )
  }
}

final class RevenueCatConfigTests: XCTestCase {
  private func key(_ info: [String: Any]?, _ env: [String: String] = [:]) -> String? {
    RevenueCatConfig.apiKey(infoDictionary: info, environment: env)
  }

  func test_readsKeyFromInfoDictionary() {
    XCTAssertEqual(key(["RevenueCatAPIKey": " appl_abc "]), "appl_abc")
  }

  func test_unsetBuildSettingLiteralIsNotAKey() {
    XCTAssertNil(key(["RevenueCatAPIKey": "$(REVENUECAT_API_KEY)"]))
    XCTAssertNil(key(["RevenueCatAPIKey": ""]))
    XCTAssertNil(key(nil))
  }

  func test_fallsBackToEnvironmentForLocalRuns() {
    let env = ["REVENUECAT_API_KEY": "appl_env"]
    XCTAssertEqual(key(["RevenueCatAPIKey": "$(REVENUECAT_API_KEY)"], env), "appl_env")
    XCTAssertEqual(key(["RevenueCatAPIKey": "appl_info"], env), "appl_info")
  }

  /// The real SDK: nothing in the app or the test host's launch has started it, and the real adapter reports the
  /// build's key (absent in the test target), never the SDK's state.
  func test_theDefaultAdapterReportsTheBuildsKey_andLaunchLeavesTheSDKStopped() {
    XCTAssertEqual(RevenueCatPurchases().hasAPIKey, RevenueCatConfig.apiKey() != nil)
    XCTAssertFalse(PurchasesLifecycle.live.isStarted(), "the app must not start RevenueCat at launch")
  }
}
