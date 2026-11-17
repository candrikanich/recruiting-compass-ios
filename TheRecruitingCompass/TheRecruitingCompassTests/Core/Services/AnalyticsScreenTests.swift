import PostHog
import XCTest
@testable import TheRecruitingCompass

/// The SDK's automatic screen capture only sees SwiftUI hosting-controller class names
/// (`NavigationStackHostingController<AnyView>`), so screens are named explicitly instead.
@MainActor
final class AnalyticsScreenTests: XCTestCase {
  nonisolated deinit {}
  private var harness: AnalyticsHarness!
  private var transport: RecordingTransport { harness.transport }

  override func setUp() {
    super.setUp()
    harness = AnalyticsHarness()
  }

  override func tearDown() {
    harness.restore()
    harness = nil
    super.tearDown()
  }

  func testConfig_turnsOffAutomaticScreenCapture() {
    XCTAssertFalse(Analytics.makeConfig(key: "phc_test").captureScreenViews)
  }

  func testScreen_sendsTheNameTaggedWithPlatform() {
    Analytics.screen("schools")

    XCTAssertEqual(transport.screens.map(\.name), ["schools"])
    XCTAssertEqual(transport.screens.first?.properties["platform"] as? String, "ios")
  }

  func testTabScreenNames_matchTheIPadSidebarDestinations() {
    let shared: [AppTab] = [.dashboard, .schools, .coaches, .interactions]
    for tab in shared {
      XCTAssertNotNil(AppDestination(rawValue: tab.screenName), "\(tab) should share its name with iPad")
    }
    XCTAssertEqual(AppTab.more.screenName, "more")
  }

  func testMorePathScreenName_namesSectionsAndSkipsDetails() {
    XCTAssertEqual(MorePath.section(.timeline).screenName, "timeline")
    XCTAssertEqual(MorePath.section(.offers).screenName, AppDestination.offers.rawValue)
    XCTAssertEqual(MorePath.familyManagement.screenName, "familyManagement")
    XCTAssertNil(MorePath.offerDetail(offerId: "o1").screenName)
    XCTAssertNil(MorePath.eventDetail(eventId: "e1").screenName)
    XCTAssertNil(MorePath.helpSection(slug: "faq").screenName)
  }
}
