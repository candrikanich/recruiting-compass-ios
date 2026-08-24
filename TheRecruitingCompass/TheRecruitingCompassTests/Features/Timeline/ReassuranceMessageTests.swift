import XCTest
@testable import TheRecruitingCompass

final class ReassuranceMessageTests: XCTestCase {
    func testDatasetHasEightEntries() {
        XCTAssertEqual(ReassuranceMessage.all.count, 8)
    }

    func testEveryEntryHasIcon() {
        XCTAssertTrue(ReassuranceMessage.all.allSatisfy { !$0.icon.isEmpty })
    }

    func testForPhaseFiltersByPhase() {
        let fr = ReassuranceMessage.forPhase(.freshman)
        XCTAssertTrue(fr.allSatisfy { $0.phases.contains(.freshman) })
    }

    func testForPhasePreservesArrayOrder() {
        let ids = ReassuranceMessage.forPhase(.senior).map(\.id)
        let expectedOrder = ReassuranceMessage.all
            .filter { $0.phases.contains(.senior) }.map(\.id)
        XCTAssertEqual(ids, expectedOrder, "must preserve source array order, no sort")
    }
}
