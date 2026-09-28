import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AppUpdateManagerTests: XCTestCase {
  nonisolated deinit {}

  private var defaults: UserDefaults!
  private var suiteName: String!
  private var now = Date(timeIntervalSince1970: 1_790_000_000)

  override func setUp() {
    super.setUp()
    suiteName = "AppUpdateManagerTests-\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    super.tearDown()
  }

  private func makeManager(
    current: String = "1.0.1",
    minimum: String? = nil,
    recommended: String? = nil,
    catalog: [WhatsNewRelease] = []
  ) -> (AppUpdateManager, MockAppVersionPolicyService) {
    let service = MockAppVersionPolicyService()
    service.policy = AppVersionPolicy(minimumVersion: minimum, recommendedVersion: recommended)
    let manager = AppUpdateManager(
      service: service,
      currentVersion: AppVersion(current)!,
      defaults: defaults,
      whatsNewCatalog: catalog,
      now: { [unowned self] in self.now }
    )
    return (manager, service)
  }

  // MARK: - Gate

  func test_belowMinimumBlocks() async {
    let (manager, _) = makeManager(current: "1.0", minimum: "1.0.1")
    await manager.check()
    XCTAssertTrue(manager.isUpdateRequired)
    XCTAssertFalse(manager.isShowingUpdatePrompt)
  }

  func test_fetchFailureFailsOpen() async {
    let (manager, service) = makeManager(current: "1.0")
    service.error = URLError(.notConnectedToInternet)
    await manager.check()
    XCTAssertEqual(manager.status, .upToDate)
    XCTAssertFalse(manager.isUpdateRequired)
  }

  func test_fetchFailureKeepsPreviouslyKnownStatus() async {
    let (manager, service) = makeManager(current: "1.0", minimum: "1.1")
    await manager.check()
    service.error = URLError(.timedOut)
    await manager.check()
    XCTAssertTrue(manager.isUpdateRequired)
  }

  func test_loweringMinimumUnblocks() async {
    let (manager, service) = makeManager(current: "1.0", minimum: "1.1")
    await manager.check()
    service.policy = AppVersionPolicy(minimumVersion: nil, recommendedVersion: nil)
    await manager.check()
    XCTAssertFalse(manager.isUpdateRequired)
  }

  // MARK: - Soft prompt

  func test_recommendedVersionShowsPromptOnce() async {
    let (manager, _) = makeManager(current: "1.0.1", recommended: "1.1")
    await manager.check()
    XCTAssertTrue(manager.isShowingUpdatePrompt)

    manager.dismissUpdatePrompt()
    XCTAssertFalse(manager.isShowingUpdatePrompt)

    await manager.check()
    XCTAssertFalse(manager.isShowingUpdatePrompt, "Dismissed version must not prompt again")
  }

  func test_dismissalPersistsAcrossLaunches() async {
    let (first, _) = makeManager(current: "1.0.1", recommended: "1.1")
    await first.check()
    first.dismissUpdatePrompt()

    let (second, _) = makeManager(current: "1.0.1", recommended: "1.1")
    await second.check()
    XCTAssertFalse(second.isShowingUpdatePrompt)
  }

  func test_newerRecommendedVersionPromptsAgain() async {
    let (manager, service) = makeManager(current: "1.0.1", recommended: "1.1")
    await manager.check()
    manager.dismissUpdatePrompt()

    service.policy = AppVersionPolicy(minimumVersion: nil, recommendedVersion: "1.2")
    await manager.check()
    XCTAssertTrue(manager.isShowingUpdatePrompt)
  }

  // MARK: - Throttling

  func test_checkIfStaleSkipsWithinAnHour() async {
    let (manager, service) = makeManager()
    await manager.checkIfStale()
    now.addTimeInterval(59 * 60)
    await manager.checkIfStale()
    XCTAssertEqual(service.fetchCount, 1)

    now.addTimeInterval(2 * 60)
    await manager.checkIfStale()
    XCTAssertEqual(service.fetchCount, 2)
  }

  func test_checkIfStaleRetriesAfterFailure() async {
    let (manager, service) = makeManager()
    service.error = URLError(.notConnectedToInternet)
    await manager.checkIfStale()
    service.error = nil
    await manager.checkIfStale()
    XCTAssertEqual(service.fetchCount, 2)
  }

  // MARK: - What's New

  private let release101 = WhatsNewRelease(
    version: AppVersion("1.0.1")!,
    highlights: [WhatsNewHighlight(systemImage: "sparkles", title: "Better", detail: "Things improved.")]
  )

  func test_freshInstallDoesNotShowWhatsNew() {
    let (manager, _) = makeManager(current: "1.0.1", catalog: [release101])
    manager.evaluateWhatsNew()
    XCTAssertNil(manager.pendingWhatsNew)
  }

  func test_upgradeShowsEntryForCurrentVersion() {
    defaults.set("1.0.0", forKey: AppUpdateManager.lastSeenVersionKey)
    let (manager, _) = makeManager(current: "1.0.1", catalog: [release101])
    manager.evaluateWhatsNew()
    XCTAssertEqual(manager.pendingWhatsNew, release101)
  }

  func test_upgradeWithoutCatalogEntryShowsNothing() {
    defaults.set("1.0.0", forKey: AppUpdateManager.lastSeenVersionKey)
    let (manager, _) = makeManager(current: "1.0.2", catalog: [release101])
    manager.evaluateWhatsNew()
    XCTAssertNil(manager.pendingWhatsNew)
  }

  func test_whatsNewShowsOnlyOncePerVersion() {
    defaults.set("1.0.0", forKey: AppUpdateManager.lastSeenVersionKey)
    let (first, _) = makeManager(current: "1.0.1", catalog: [release101])
    first.evaluateWhatsNew()
    XCTAssertNotNil(first.pendingWhatsNew)
    first.dismissWhatsNew()
    XCTAssertNil(first.pendingWhatsNew)

    let (second, _) = makeManager(current: "1.0.1", catalog: [release101])
    second.evaluateWhatsNew()
    XCTAssertNil(second.pendingWhatsNew)
  }

  func test_sameVersionRelaunchShowsNothing() {
    defaults.set("1.0.1", forKey: AppUpdateManager.lastSeenVersionKey)
    let (manager, _) = makeManager(current: "1.0.1", catalog: [release101])
    manager.evaluateWhatsNew()
    XCTAssertNil(manager.pendingWhatsNew)
  }
}
