import Helpers
import Supabase
import XCTest
@testable import TheRecruitingCompass

private func httpError(status: Int) -> HTTPError {
  let url = URL(string: "https://example.invalid/rest/v1/events")!
  let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
  return HTTPError(data: Data(), response: response)
}

private let rlsDenied = PostgrestError(code: "42501", message: "new row violates row-level security policy")
private let subscriptionMessage = WriteGate.subscriptionMessage

// MARK: - EntitlementStore.isReadOnly

@MainActor
final class EntitlementReadOnlyTests: XCTestCase {
  nonisolated deinit {}

  private func loadedStore(_ status: SubscriptionStatus, trialEndsAt: Date? = nil) async -> EntitlementStore {
    let mock = MockEntitlementService()
    mock.subscription = FamilySubscription(
      familyUnitId: "fam-1", status: status, source: "test", trialEndsAt: trialEndsAt, currentPeriodEnd: nil
    )
    let store = EntitlementStore(service: mock)
    await store.load(familyUnitId: "fam-1")
    return store
  }

  func testReadOnlyAndUnknownStatuses_areReadOnly() async {
    for status in [SubscriptionStatus.readOnly, .unknown] {
      let store = await loadedStore(status)
      XCTAssertTrue(store.isReadOnly, "\(status)")
    }
  }

  func testExpiredTrial_isReadOnly() async {
    let store = await loadedStore(.trialing, trialEndsAt: Date().addingTimeInterval(-3600))
    XCTAssertTrue(store.isReadOnly)
  }

  func testWritablePlans_areNeverReadOnly() async {
    for status in [SubscriptionStatus.founding, .active, .comp] {
      let store = await loadedStore(status)
      XCTAssertFalse(store.isReadOnly, "\(status)")
    }
    let trial = await loadedStore(.trialing, trialEndsAt: Date().addingTimeInterval(86_400))
    XCTAssertFalse(trial.isReadOnly)
  }

  func testNotLoadedYet_isNotReadOnly() {
    XCTAssertFalse(EntitlementStore(service: MockEntitlementService()).isReadOnly)
  }

  func testLoadFailure_isNotReadOnly() async {
    struct Boom: Error {}
    let mock = MockEntitlementService()
    mock.error = Boom()
    let store = EntitlementStore(service: mock)
    await store.load(familyUnitId: "fam-1")
    XCTAssertTrue(store.hasLoaded)
    XCTAssertFalse(store.isReadOnly)
  }

  func testFamilyWithNoSubscriptionRow_isNotReadOnly() async {
    let mock = MockEntitlementService()
    mock.subscription = nil
    let store = EntitlementStore(service: mock)
    await store.load(familyUnitId: "fam-1")
    XCTAssertFalse(store.isReadOnly)
  }
}

// MARK: - WriteGate

@MainActor
final class WriteGateTests: XCTestCase {
  nonisolated deinit {}

  func testDefaultGate_failsOpen() {
    let gate = WriteGate()
    XCTAssertFalse(gate.blocksWrite())
    XCTAssertFalse(gate.isShowingNotice)
    XCTAssertNil(gate.subscriptionMessage(for: rlsDenied))
  }

  func testBlocksWrite_readOnly_blocksAndShowsNotice() {
    let gate = WriteGate()
    gate.isReadOnly = { true }
    gate.role = { .parent }
    XCTAssertTrue(gate.blocksWrite())
    XCTAssertTrue(gate.isShowingNotice)
  }

  func testBlocksWrite_writable_allowsAndStaysQuiet() {
    let gate = WriteGate()
    gate.isReadOnly = { false }
    gate.role = { .parent }
    XCTAssertFalse(gate.blocksWrite())
    XCTAssertFalse(gate.isShowingNotice)
  }

  /// Every member of readOnly x failure: only a permission failure on a read-only plan gets the subscription copy.
  func testSubscriptionMessage_coversEveryStateAndError() {
    let cases: [(readOnly: Bool, error: Error, expectsSubscription: Bool)] = [
      (true, rlsDenied, true),
      (true, httpError(status: 403), true),
      (true, httpError(status: 500), false),
      (true, PostgrestError(code: "22P02", message: "invalid uuid"), false),
      (true, URLError(.notConnectedToInternet), false),
      (false, rlsDenied, false),
      (false, httpError(status: 403), false),
      (false, httpError(status: 500), false),
      (false, URLError(.notConnectedToInternet), false)
    ]
    for testCase in cases {
      let gate = WriteGate()
      gate.isReadOnly = { testCase.readOnly }
      gate.role = { .parent }
      let message = gate.subscriptionMessage(for: testCase.error)
      XCTAssertEqual(message, testCase.expectsSubscription ? subscriptionMessage : nil, "\(testCase)")
    }
  }

  /// Web (web#1234) copies these strings word for word.
  func testNoticeCopy_isPinnedWordForWord() {
    XCTAssertEqual(WriteGate.noticeTitle, "Read-only plan")
    XCTAssertEqual(
      WriteGate.subscriptionMessage,
      "Your plan is read-only right now. Renew your subscription to add or change anything."
    )
    XCTAssertEqual(WriteGate.viewPlanButton, "View plan")
    XCTAssertEqual(WriteGate.closeButton, "Close")
  }

  func testMapping_followsCannotWriteWhileBlockingFollowsIsReadOnly() {
    let gate = WriteGate()
    gate.isReadOnly = { false }
    gate.role = { .parent }
    gate.cannotWrite = { true }
    XCTAssertFalse(gate.blocksWrite())
    XCTAssertEqual(gate.subscriptionMessage(for: rlsDenied), subscriptionMessage)
    XCTAssertEqual(gate.subscriptionMessage(for: httpError(status: 403)), subscriptionMessage)
    XCTAssertNil(gate.subscriptionMessage(for: httpError(status: 500)))

    gate.isReadOnly = { true }
    gate.role = { .parent }
    gate.cannotWrite = { false }
    XCTAssertTrue(gate.blocksWrite())
    XCTAssertNil(gate.subscriptionMessage(for: rlsDenied))
  }

  func testAttach_failedPlanLoad_mapsButNeverBlocks() async {
    struct Boom: Error {}
    let service = MockEntitlementService()
    service.error = Boom()
    let store = EntitlementStore(service: service)
    await store.load(familyUnitId: "fam-1")
    let gate = WriteGate()
    gate.attach(to: store, role: { .parent })
    XCTAssertFalse(gate.blocksWrite())
    XCTAssertEqual(gate.subscriptionMessage(for: rlsDenied), subscriptionMessage)
  }

  func testAttach_planStillLoading_mapsButNeverBlocks() {
    let gate = WriteGate()
    gate.attach(to: EntitlementStore(service: MockEntitlementService()), role: { .parent })
    XCTAssertFalse(gate.blocksWrite())
    XCTAssertEqual(gate.subscriptionMessage(for: rlsDenied), subscriptionMessage)
  }

  func testAttach_writablePlan_neverBlocksOrMaps() async {
    let service = MockEntitlementService()
    service.subscription = FamilySubscription(
      familyUnitId: "fam-1", status: .active, source: "test", trialEndsAt: nil, currentPeriodEnd: nil
    )
    let store = EntitlementStore(service: service)
    await store.load(familyUnitId: "fam-1")
    let gate = WriteGate()
    gate.attach(to: store, role: { .parent })
    XCTAssertFalse(gate.blocksWrite())
    XCTAssertNil(gate.subscriptionMessage(for: rlsDenied))
  }

  func testAttach_readOnlyPlan_blocksAndMaps() async {
    let service = MockEntitlementService()
    service.subscription = FamilySubscription(
      familyUnitId: "fam-1", status: .readOnly, source: "test", trialEndsAt: nil, currentPeriodEnd: nil
    )
    let store = EntitlementStore(service: service)
    await store.load(familyUnitId: "fam-1")
    let gate = WriteGate()
    gate.attach(to: store, role: { .parent })
    XCTAssertTrue(gate.blocksWrite())
    XCTAssertEqual(gate.subscriptionMessage(for: rlsDenied), subscriptionMessage)
  }

  func testSubscriptionCopy_followsTheVoiceGuide() {
    XCTAssertFalse(subscriptionMessage.contains("TRC"))
    XCTAssertFalse(subscriptionMessage.lowercased().contains("permission"))
    XCTAssertFalse(WriteGate.noticeTitle.contains("TRC"))
  }

  // MARK: Role-aware notice (parents only buy, Chris 2026-11-24)

  /// Every member of the role set: only a parent is told to renew; an athlete and a missing role are not.
  func testNotice_onlyAParentIsToldToRenew() {
    let expected: [(role: UserRole?, message: String)] = [
      (.parent, subscriptionMessage),
      (.player, WriteGate.askAParentMessage),
      (nil, WriteGate.askAParentMessage)
    ]
    for testCase in expected {
      let gate = WriteGate()
      gate.isReadOnly = { true }
      gate.role = { testCase.role }
      XCTAssertEqual(gate.noticeMessage, testCase.message, "\(String(describing: testCase.role))")
      XCTAssertEqual(gate.subscriptionMessage(for: rlsDenied), testCase.message, "\(String(describing: testCase.role))")
      XCTAssertEqual(gate.subscriptionMessage(for: httpError(status: 403)), testCase.message)
    }
  }

  func testNotice_followsTheRoleAtTheMomentOfUse() {
    var role: UserRole? = .parent
    let gate = WriteGate()
    gate.isReadOnly = { true }
    gate.role = { role }
    XCTAssertEqual(gate.noticeMessage, subscriptionMessage)
    role = .player
    XCTAssertEqual(gate.noticeMessage, WriteGate.askAParentMessage)
  }

  func testAttach_wiresTheRoleIntoTheNotice() {
    let gate = WriteGate()
    gate.attach(to: EntitlementStore(service: MockEntitlementService()), role: { .player })
    XCTAssertEqual(gate.subscriptionMessage(for: rlsDenied), WriteGate.askAParentMessage)
  }

  func testAthleteNotice_isPinnedAndHasNoRenewPriceOrPressure() {
    XCTAssertEqual(
      WriteGate.askAParentMessage,
      "Your plan is read-only right now. A parent can choose a plan for your family."
    )
    XCTAssertTrue(WriteGate.askAParentMessage.contains(PaywallAccess.askAParentCopy))
    let copy = WriteGate.askAParentMessage.lowercased()
    for word in ["renew", "subscri", "$", "pay", "hurry", "limited", "expire", "trc"] {
      XCTAssertFalse(copy.contains(word), word)
    }
  }
}

// MARK: - Events

@MainActor
final class ReadOnlyEventsViewModelTests: XCTestCase {
  nonisolated deinit {}

  private var service: MockEventsService!
  private var auth: MockAuthManager!
  private var holder: [Any] = []

  override func setUp() {
    super.setUp()
    service = MockEventsService()
    auth = MockAuthManager()
    auth.setMockUser(User(
      id: "test-user-id", email: "t@example.com", emailConfirmedAt: "2025-01-01T00:00:00Z",
      createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z", role: .player
    ))
  }

  override func tearDown() {
    holder = []
    service = nil
    auth = nil
    super.tearDown()
  }

  private func makeCreate(readOnly: Bool) -> CreateEventViewModel {
    let vm = CreateEventViewModel(eventsService: service, userId: "test-user-id", familyUnitId: "fam-1")
    vm.writeGate.isReadOnly = { readOnly }
    vm.writeGate.role = { .parent }
    vm.formData.type = .showcase
    vm.formData.name = "Test Event"
    vm.formData.startDate = Date(timeIntervalSince1970: 1_780_000_000)
    holder.append(vm)
    return vm
  }

  private func makeDetail(readOnly: Bool) async -> EventDetailViewModel {
    let familyManager = FamilyManager(familyService: MockFamilyService(), authManager: auth)
    familyManager.currentMember = FamilyMember(
      id: "m1", userId: "test-user-id", familyUnitId: "fam-1", role: "athlete",
      addedAt: "2025-01-01T00:00:00Z", user: nil
    )
    service.stubbedFetchedEvent = .mock(attended: false)
    let vm = EventDetailViewModel(
      eventsService: service, familyManager: familyManager, authManager: auth, eventId: "test-event-id"
    )
    await vm.loadAll()
    vm.writeGate.isReadOnly = { readOnly }
    vm.writeGate.role = { .parent }
    holder.append(vm)
    return vm
  }

  // Create

  func testCreateEvent_readOnly_isBlockedBeforeTheNetwork() async {
    let vm = makeCreate(readOnly: true)
    let id = await vm.createEvent()
    XCTAssertNil(id)
    XCTAssertEqual(service.createEventCallCount, 0)
    XCTAssertTrue(vm.writeGate.isShowingNotice)
  }

  func testCreateEvent_writable_goesThroughWithoutNotice() async {
    let vm = makeCreate(readOnly: false)
    let id = await vm.createEvent()
    XCTAssertNotNil(id)
    XCTAssertEqual(service.createEventCallCount, 1)
    XCTAssertFalse(vm.writeGate.isShowingNotice)
  }

  /// The plan reads writable when the write is attempted and lapsed by the time the server refuses it.
  func testCreateEvent_refusedAfterPlanLapsed_showsSubscriptionMessage() async {
    let vm = makeCreate(readOnly: false)
    service.createEventError = rlsDenied
    var calls = 0
    vm.writeGate.isReadOnly = { calls += 1; return calls > 1 }
    vm.writeGate.role = { .parent }
    _ = await vm.createEvent()
    XCTAssertEqual(vm.errorMessage, subscriptionMessage)
  }

  func testCreateEvent_writableAnd42501_keepsPermissionMessage() async {
    let vm = makeCreate(readOnly: false)
    service.createEventError = rlsDenied
    _ = await vm.createEvent()
    XCTAssertTrue(vm.errorMessage?.contains("permission") == true)
    XCTAssertNotEqual(vm.errorMessage, subscriptionMessage)
  }

  func testCreateEvent_networkErrorAfterPlanLapsed_isNotMistakenForSubscription() async {
    let vm = makeCreate(readOnly: false)
    service.createEventError = URLError(.notConnectedToInternet)
    var calls = 0
    vm.writeGate.isReadOnly = { calls += 1; return calls > 1 }
    vm.writeGate.role = { .parent }
    _ = await vm.createEvent()
    XCTAssertNotEqual(vm.errorMessage, subscriptionMessage)
    XCTAssertNotNil(vm.errorMessage)
  }

  // Detail edit / delete / attended

  func testOpenEditForm_readOnly_blocksAndNotices() async {
    let vm = await makeDetail(readOnly: true)
    vm.openEditForm()
    XCTAssertFalse(vm.showEditSheet)
    XCTAssertTrue(vm.writeGate.isShowingNotice)
  }

  func testOpenEditForm_writable_opensSheet() async {
    let vm = await makeDetail(readOnly: false)
    vm.openEditForm()
    XCTAssertTrue(vm.showEditSheet)
    XCTAssertFalse(vm.writeGate.isShowingNotice)
  }

  func testUpdateEvent_readOnly_doesNotWrite() async {
    let vm = await makeDetail(readOnly: false)
    vm.openEditForm()
    vm.writeGate.isReadOnly = { true }
    vm.writeGate.role = { .parent }
    await vm.updateEvent()
    XCTAssertEqual(service.updateEventCallCount, 0)
    XCTAssertTrue(vm.writeGate.isShowingNotice)
  }

  func testUpdateEvent_failureOnReadOnlyPlan_mapsEveryErrorKind() async {
    let cases: [(error: Error, readOnly: Bool, expectsSubscription: Bool)] = [
      (rlsDenied, true, true), (httpError(status: 403), true, true), (httpError(status: 500), true, false),
      (rlsDenied, false, false), (URLError(.notConnectedToInternet), false, false)
    ]
    for testCase in cases {
      let vm = await makeDetail(readOnly: false)
      vm.openEditForm()
      service.writeError = testCase.error
      let flips = testCase.readOnly
      var calls = 0
      // Writable when the write is attempted, read-only by the time it fails (plan lapsed meanwhile).
      vm.writeGate.isReadOnly = { calls += 1; return flips && calls > 1 }
      vm.writeGate.role = { .parent }
      await vm.updateEvent()
      XCTAssertEqual(
        vm.errorMessage == subscriptionMessage, testCase.expectsSubscription, "\(testCase)"
      )
      XCTAssertNotNil(vm.errorMessage, "\(testCase)")
    }
  }

  func testMarkAsAttended_readOnly_doesNotWrite() async {
    let vm = await makeDetail(readOnly: true)
    await vm.markAsAttended()
    XCTAssertEqual(service.updateEventCallCount, 0)
    XCTAssertTrue(vm.writeGate.isShowingNotice)
  }

  func testConfirmDelete_readOnly_doesNotAskToConfirm() async {
    let vm = await makeDetail(readOnly: true)
    vm.confirmDelete()
    XCTAssertFalse(vm.showDeleteConfirmation)
    XCTAssertTrue(vm.writeGate.isShowingNotice)
  }

  func testConfirmDelete_writable_asksToConfirm() async {
    let vm = await makeDetail(readOnly: false)
    vm.confirmDelete()
    XCTAssertTrue(vm.showDeleteConfirmation)
  }

  func testDeleteEvent_readOnly_doesNotWrite() async {
    let vm = await makeDetail(readOnly: true)
    await vm.deleteEvent()
    XCTAssertEqual(service.deleteEventCallCount, 0)
    XCTAssertFalse(vm.shouldDismiss)
  }

  func testDeleteEvent_refusedOnReadOnlyPlan_showsSubscriptionMessage() async {
    let vm = await makeDetail(readOnly: false)
    service.writeError = httpError(status: 403)
    var calls = 0
    vm.writeGate.isReadOnly = { calls += 1; return calls > 1 }
    vm.writeGate.role = { .parent }
    await vm.deleteEvent()
    XCTAssertEqual(vm.errorMessage, subscriptionMessage)
  }

  // List entry point

  func testCanStartCreateEvent_readOnlyBlocksWritableAllows() {
    let blocked = EventsListViewModel(eventsService: service, authManager: auth, cache: InMemoryCache())
    blocked.writeGate.isReadOnly = { true }
    blocked.writeGate.role = { .parent }
    XCTAssertFalse(blocked.canStartCreateEvent())
    XCTAssertTrue(blocked.writeGate.isShowingNotice)

    let open = EventsListViewModel(eventsService: service, authManager: auth, cache: InMemoryCache())
    open.writeGate.isReadOnly = { false }
    open.writeGate.role = { .parent }
    XCTAssertTrue(open.canStartCreateEvent())
    XCTAssertFalse(open.writeGate.isShowingNotice)
    holder.append(contentsOf: [blocked, open])
  }

  func testCanStartDeleteEvent_readOnlyBlocksWritableAllows() {
    let blocked = EventsListViewModel(eventsService: service, authManager: auth, cache: InMemoryCache())
    blocked.writeGate.isReadOnly = { true }
    blocked.writeGate.role = { .parent }
    XCTAssertFalse(blocked.canStartDeleteEvent())
    XCTAssertTrue(blocked.writeGate.isShowingNotice)

    let open = EventsListViewModel(eventsService: service, authManager: auth, cache: InMemoryCache())
    open.writeGate.isReadOnly = { false }
    open.writeGate.role = { .parent }
    XCTAssertTrue(open.canStartDeleteEvent())
    XCTAssertFalse(open.writeGate.isShowingNotice)
    holder.append(contentsOf: [blocked, open])
  }

  func testDeleteEvent_readOnly_makesNoCallAndKeepsTheRow() async {
    let vm = EventsListViewModel(eventsService: service, authManager: auth, cache: InMemoryCache())
    vm.events = [.mock(id: "e1")]
    vm.writeGate.isReadOnly = { true }
    vm.writeGate.role = { .parent }
    await vm.deleteEvent(id: "e1")
    XCTAssertEqual(service.deleteEventCallCount, 0)
    XCTAssertEqual(vm.events.map(\.id), ["e1"])
    XCTAssertTrue(vm.writeGate.isShowingNotice)
    holder.append(vm)
  }

  func testDeleteEvent_writable_removesTheRow() async {
    let vm = EventsListViewModel(eventsService: service, authManager: auth, cache: InMemoryCache())
    vm.events = [.mock(id: "e1")]
    vm.writeGate.isReadOnly = { false }
    vm.writeGate.role = { .parent }
    await vm.deleteEvent(id: "e1")
    XCTAssertEqual(service.deleteEventCallCount, 1)
    XCTAssertTrue(vm.events.isEmpty)
    holder.append(vm)
  }

  /// The plan has not loaded (or failed to load), so nothing blocks the write; the server then refuses it.
  func testCreateEvent_planNotKnown_refusedByServer_showsSubscriptionMessage() async {
    let vm = makeCreate(readOnly: false)
    vm.writeGate.isReadOnly = { false }
    vm.writeGate.role = { .parent }
    vm.writeGate.cannotWrite = { true }
    service.createEventError = rlsDenied
    _ = await vm.createEvent()
    XCTAssertEqual(service.createEventCallCount, 1)
    XCTAssertEqual(vm.errorMessage, subscriptionMessage)
  }

  func testCreateEvent_planKnownWritable_refusedByServer_keepsPermissionMessage() async {
    let vm = makeCreate(readOnly: false)
    vm.writeGate.cannotWrite = { false }
    service.createEventError = rlsDenied
    _ = await vm.createEvent()
    XCTAssertTrue(vm.errorMessage?.contains("permission") == true)
  }
}

// MARK: - Offers

@MainActor
final class ReadOnlyOffersViewModelTests: XCTestCase {
  nonisolated deinit {}

  private var service: MockOffersService!
  private var auth: MockAuthManager!
  private var holder: [Any] = []

  override func setUp() {
    super.setUp()
    service = MockOffersService()
    auth = MockAuthManager()
    auth.setMockUser(User(
      id: "test-user-id", email: "t@example.com", emailConfirmedAt: "2025-01-01T00:00:00Z",
      createdAt: "2025-01-01T00:00:00Z", updatedAt: "2025-01-01T00:00:00Z", role: .player
    ))
  }

  override func tearDown() {
    holder = []
    service = nil
    auth = nil
    super.tearDown()
  }

  private func makeList(readOnly: Bool) -> OffersListViewModel {
    let familyManager = FamilyManager(familyService: MockFamilyService(), authManager: auth)
    familyManager.currentMember = FamilyMember(
      id: "m1", userId: "test-user-id", familyUnitId: "fam-1", role: "athlete",
      addedAt: "2025-01-01T00:00:00Z", user: nil
    )
    let vm = OffersListViewModel(
      offersService: service, familyManager: familyManager, authManager: auth, cache: InMemoryCache()
    )
    vm.writeGate.isReadOnly = { readOnly }
    vm.writeGate.role = { .parent }
    holder.append(vm)
    return vm
  }

  private func makeDetail(readOnly: Bool) -> OfferDetailViewModel {
    let vm = OfferDetailViewModel(
      offerId: "offer-1", offersService: service, authManager: auth, cache: InMemoryCache()
    )
    vm.offer = makeTestOffer(id: "offer-1")
    vm.writeGate.isReadOnly = { readOnly }
    vm.writeGate.role = { .parent }
    holder.append(vm)
    return vm
  }

  // List: add form

  func testToggleAddForm_readOnly_staysClosedAndNotices() {
    let vm = makeList(readOnly: true)
    vm.toggleAddForm()
    XCTAssertFalse(vm.showAddForm)
    XCTAssertTrue(vm.writeGate.isShowingNotice)
  }

  func testToggleAddForm_writable_opensThenCloses() {
    let vm = makeList(readOnly: false)
    vm.toggleAddForm()
    XCTAssertTrue(vm.showAddForm)
    vm.toggleAddForm()
    XCTAssertFalse(vm.showAddForm)
    XCTAssertFalse(vm.writeGate.isShowingNotice)
  }

  func testToggleAddForm_planLapsesWhileFormOpen_stillLetsTheFormClose() {
    let vm = makeList(readOnly: false)
    vm.toggleAddForm()
    vm.writeGate.isReadOnly = { true }
    vm.writeGate.role = { .parent }
    vm.toggleAddForm()
    XCTAssertFalse(vm.showAddForm)
  }

  func testOpenAddForm_readOnlyBlocksWritableOpens() {
    let blocked = makeList(readOnly: true)
    blocked.openAddForm()
    XCTAssertFalse(blocked.showAddForm)
    XCTAssertTrue(blocked.writeGate.isShowingNotice)
    let open = makeList(readOnly: false)
    open.openAddForm()
    XCTAssertTrue(open.showAddForm)
  }

  // List: create / delete

  func testCreateOffer_readOnly_doesNotWrite() async {
    let vm = makeList(readOnly: true)
    vm.formState.schoolId = "school-1"
    await vm.createOffer()
    XCTAssertEqual(service.createOfferCallCount, 0)
    XCTAssertTrue(vm.writeGate.isShowingNotice)
  }

  func testCreateOffer_writable_writes() async {
    let vm = makeList(readOnly: false)
    vm.formState.schoolId = "school-1"
    await vm.createOffer()
    XCTAssertEqual(service.createOfferCallCount, 1)
  }

  func testCreateOffer_failureCoversEveryStateAndError() async {
    let cases: [(error: Error, readOnly: Bool, expectsSubscription: Bool)] = [
      (rlsDenied, true, true), (httpError(status: 403), true, true), (httpError(status: 500), true, false),
      (rlsDenied, false, false), (httpError(status: 403), false, false), (URLError(.timedOut), false, false)
    ]
    for testCase in cases {
      let vm = makeList(readOnly: false)
      vm.formState.schoolId = "school-1"
      service.writeError = testCase.error
      var calls = 0
      vm.writeGate.isReadOnly = { calls += 1; return testCase.readOnly && calls > 1 }
      vm.writeGate.role = { .parent }
      await vm.createOffer()
      XCTAssertEqual(vm.errorMessage == subscriptionMessage, testCase.expectsSubscription, "\(testCase)")
      XCTAssertNotNil(vm.errorMessage, "\(testCase)")
    }
  }

  func testConfirmDelete_readOnly_doesNotAsk() {
    let vm = makeList(readOnly: true)
    vm.confirmDelete(makeTestOffer(id: "o1"))
    XCTAssertFalse(vm.showDeleteConfirmation)
    XCTAssertNil(vm.offerToDelete)
    XCTAssertTrue(vm.writeGate.isShowingNotice)
  }

  func testDeleteOffer_readOnly_doesNotWriteAndClearsPending() async {
    let vm = makeList(readOnly: false)
    let offer = makeTestOffer(id: "o1")
    vm.allOffers = [offer]
    vm.confirmDelete(offer)
    vm.writeGate.isReadOnly = { true }
    vm.writeGate.role = { .parent }
    await vm.deleteOffer()
    XCTAssertEqual(service.deleteOfferCallCount, 0)
    XCTAssertEqual(vm.allOffers.count, 1)
    XCTAssertFalse(vm.showDeleteConfirmation)
    XCTAssertNil(vm.offerToDelete)
  }

  func testDeleteOffer_refusedOnReadOnlyPlan_showsSubscriptionMessage() async {
    let vm = makeList(readOnly: false)
    let offer = makeTestOffer(id: "o1")
    vm.allOffers = [offer]
    vm.confirmDelete(offer)
    service.writeError = rlsDenied
    var calls = 0
    vm.writeGate.isReadOnly = { calls += 1; return calls > 1 }
    vm.writeGate.role = { .parent }
    await vm.deleteOffer()
    XCTAssertEqual(vm.errorMessage, subscriptionMessage)
  }

  func testDeleteOffer_refusedOnWritablePlan_keepsGenericMessage() async {
    let vm = makeList(readOnly: false)
    let offer = makeTestOffer(id: "o1")
    vm.allOffers = [offer]
    vm.confirmDelete(offer)
    service.writeError = rlsDenied
    await vm.deleteOffer()
    XCTAssertEqual(vm.errorMessage, "Failed to delete offer. Please try again.")
  }

  // Detail: edit / save / delete

  func testStartEditing_readOnly_blocksAndNotices() {
    let vm = makeDetail(readOnly: true)
    vm.startEditing()
    XCTAssertFalse(vm.isEditing)
    XCTAssertTrue(vm.writeGate.isShowingNotice)
  }

  func testStartEditing_writable_startsEditing() {
    let vm = makeDetail(readOnly: false)
    vm.startEditing()
    XCTAssertTrue(vm.isEditing)
  }

  func testSaveChanges_readOnly_doesNotWrite() async {
    let vm = makeDetail(readOnly: false)
    vm.startEditing()
    vm.writeGate.isReadOnly = { true }
    vm.writeGate.role = { .parent }
    await vm.saveChanges()
    XCTAssertEqual(service.updateOfferCallCount, 0)
    XCTAssertTrue(vm.writeGate.isShowingNotice)
  }

  func testSaveChanges_failureCoversEveryStateAndError() async {
    let cases: [(error: Error, readOnly: Bool, expectsSubscription: Bool)] = [
      (rlsDenied, true, true), (httpError(status: 403), true, true), (httpError(status: 500), true, false),
      (rlsDenied, false, false), (URLError(.timedOut), false, false)
    ]
    for testCase in cases {
      let vm = makeDetail(readOnly: false)
      vm.startEditing()
      service.writeError = testCase.error
      var calls = 0
      vm.writeGate.isReadOnly = { calls += 1; return testCase.readOnly && calls > 1 }
      vm.writeGate.role = { .parent }
      await vm.saveChanges()
      guard case .error(let message) = vm.activeAlert else { return XCTFail("no error alert for \(testCase)") }
      XCTAssertEqual(message == subscriptionMessage, testCase.expectsSubscription, "\(testCase)")
    }
  }

  func testConfirmDelete_detailReadOnly_doesNotAsk() {
    let vm = makeDetail(readOnly: true)
    vm.confirmDelete()
    XCTAssertNil(vm.activeAlert)
    XCTAssertTrue(vm.writeGate.isShowingNotice)
  }

  func testConfirmDelete_detailWritable_asks() {
    let vm = makeDetail(readOnly: false)
    vm.confirmDelete()
    XCTAssertNotNil(vm.activeAlert)
  }

  func testDeleteOffer_detailReadOnly_doesNotWrite() async {
    let vm = makeDetail(readOnly: true)
    let deleted = await vm.deleteOffer()
    XCTAssertFalse(deleted)
    XCTAssertEqual(service.deleteOfferCallCount, 0)
  }

  func testDeleteOffer_detailRefusedOnReadOnlyPlan_showsSubscriptionMessage() async {
    let vm = makeDetail(readOnly: false)
    service.writeError = httpError(status: 403)
    var calls = 0
    vm.writeGate.isReadOnly = { calls += 1; return calls > 1 }
    vm.writeGate.role = { .parent }
    _ = await vm.deleteOffer()
    guard case .deleteError(let message) = vm.activeAlert else { return XCTFail("no delete alert") }
    XCTAssertEqual(message, subscriptionMessage)
  }
}
