import XCTest
@testable import TheRecruitingCompass

@MainActor
final class BillingSessionTests: XCTestCase {
  nonisolated deinit {}

  private let uid = "3f2b8c1e-9a4d-4e6f-8b1a-5c7d9e0f1a2b"

  func test_logsInWithTheLowercasedSupabaseUserIdAndNothingElse() async {
    let fake = FakePurchases()
    let session = BillingSession(purchases: fake)
    await session.sync(userId: uid.uppercased())
    XCTAssertEqual(fake.logInCalls, [uid])
    XCTAssertTrue(session.isIdentified(as: uid))
    XCTAssertTrue(session.isIdentified(as: uid.uppercased()))
  }

  func test_notIdentifiedUntilLoginFinishes() async {
    let fake = FakePurchases()
    let gate = AsyncGate()
    fake.logInGate = { _ in await gate.wait() }
    let session = BillingSession(purchases: fake)
    let pending = Task { await session.sync(userId: uid) }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    XCTAssertFalse(session.isIdentified(as: uid))
    gate.open()
    await pending.value
    XCTAssertTrue(session.isIdentified(as: uid))
  }

  func test_aSlowLoginForAnAccountTheUserLeftCannotUnlockTheNextOne() async {
    let fake = FakePurchases()
    let gate = AsyncGate(blockedEntries: 1)
    fake.logInGate = { _ in await gate.wait() }
    let session = BillingSession(purchases: fake)
    let first = Task { await session.sync(userId: "aaaaaaaa-0000-0000-0000-000000000001") }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)
    await session.sync(userId: "bbbbbbbb-0000-0000-0000-000000000002")
    gate.open()
    await first.value
    XCTAssertFalse(session.isIdentified(as: "aaaaaaaa-0000-0000-0000-000000000001"))
    XCTAssertTrue(session.isIdentified(as: "bbbbbbbb-0000-0000-0000-000000000002"))
  }

  func test_aFailedLoginLeavesPurchasesLocked_andEnsureIdentifiedRetries() async {
    let fake = FakePurchases()
    fake.logInError = FakePurchasesFailure()
    let session = BillingSession(purchases: fake)
    await session.sync(userId: uid)
    XCTAssertFalse(session.isIdentified(as: uid))
    fake.logInError = nil
    let recovered = await session.ensureIdentified(as: uid)
    XCTAssertTrue(recovered)
    XCTAssertEqual(fake.logInCalls.count, 2)
  }

  func test_signOutDetachesTheCustomerAndLocksPurchases() async {
    let fake = FakePurchases()
    let session = BillingSession(purchases: fake)
    await session.sync(userId: uid)
    await session.sync(userId: nil)
    XCTAssertEqual(fake.logOutCount, 1)
    XCTAssertFalse(session.isIdentified(as: uid))
    XCTAssertNil(session.identifiedUserId)
  }

  func test_noUserIsNeverIdentified() async {
    let session = BillingSession(purchases: FakePurchases())
    XCTAssertFalse(session.isIdentified(as: nil))
    let identified = await session.ensureIdentified(as: nil)
    XCTAssertFalse(identified)
  }

  func test_currentProductIsOnlyReadForAnIdentifiedUser() async {
    let fake = FakePurchases()
    fake.currentProduct = "trc_players_1_annual"
    fake.logInError = FakePurchasesFailure()
    let session = BillingSession(purchases: fake)
    let whileLocked = await session.currentProductId(as: uid)
    XCTAssertNil(whileLocked)
    fake.logInError = nil
    let unlocked = await session.currentProductId(as: uid)
    XCTAssertEqual(unlocked, "trc_players_1_annual")
  }
}
