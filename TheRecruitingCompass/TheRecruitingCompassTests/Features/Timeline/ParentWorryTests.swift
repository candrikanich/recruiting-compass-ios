import XCTest
@testable import TheRecruitingCompass

final class ParentWorryTests: XCTestCase {
    func testDatasetHasFifteenEntries() {
        XCTAssertEqual(ParentWorry.all.count, 15)
    }

    func testAllPhasesNonEmpty() {
        for worry in ParentWorry.all {
            XCTAssertFalse(worry.phases.isEmpty, "\(worry.id) has no phases")
        }
    }

    func testForPhaseFiltersByPhase() {
        let junior = ParentWorry.forPhase(.junior)
        XCTAssertFalse(junior.isEmpty)
        XCTAssertTrue(junior.allSatisfy { $0.phases.contains(.junior) })
    }

    func testForPhaseSortedByCategoryAlphabetical() {
        let sorted = ParentWorry.forPhase(.senior)
        let cats = sorted.map { $0.category.rawValue }
        XCTAssertEqual(cats, cats.sorted(), "must be category-alphabetical")
    }

    func testCommittedFallsBackToSenior() {
        XCTAssertEqual(ParentWorry.forPhase(.committed).map(\.id),
                       ParentWorry.forPhase(.senior).map(\.id))
    }
}
