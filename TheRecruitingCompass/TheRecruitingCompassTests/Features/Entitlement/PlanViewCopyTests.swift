import XCTest
@testable import TheRecruitingCompass

/// Plan billing is per player (web#1510): one player per plan, siblings are billed separately.
final class PlanViewCopyTests: XCTestCase {
  func testFooterDescribesPerPlayerPlan() {
    XCTAssertEqual(
      PlanView.footerCopy,
      "Your plan covers one player's family. Each sibling gets their own family."
    )
  }

  func testFooterDropsWholeFamilyClaim() {
    XCTAssertFalse(PlanView.footerCopy.contains("whole family"))
    XCTAssertFalse(PlanView.footerCopy.contains("every parent and athlete"))
    XCTAssertFalse(PlanView.footerCopy.contains("additional sibling"))
    XCTAssertFalse(PlanView.footerCopy.contains("sibling's family"))
  }
}
