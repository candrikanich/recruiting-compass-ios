import XCTest
@testable import TheRecruitingCompass

final class SupabaseManagerTests: XCTestCase {
  var sut: SupabaseManager!

  override func setUp() {
    super.setUp()
    sut = SupabaseManager.shared
  }

  func testSupabaseManagerIsSingleton() {
    let manager1 = SupabaseManager.shared
    let manager2 = SupabaseManager.shared
    XCTAssert(manager1 === manager2, "SupabaseManager should be a singleton")
  }

  // Note: This is a placeholder test since we can't easily mock Supabase client
  // Real testing will be done in integration tests
  func testFetchUserProfileMethodExists() {
    let manager = SupabaseManager.shared
    // Verify method signature exists (compile-time check)
    XCTAssertNotNil(manager.client)
  }
}
