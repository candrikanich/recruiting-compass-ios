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

  func testFooterDropsOriginalAndFirstRoundWording() {
    let denied = [
      "whole family", "every parent and athlete", "additional sibling", "sibling's family", "sibling player"
    ]
    for old in denied {
      XCTAssertNil(PlanView.footerCopy.range(of: old, options: .caseInsensitive), old)
    }
  }
}
