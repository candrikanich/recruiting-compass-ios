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
}
