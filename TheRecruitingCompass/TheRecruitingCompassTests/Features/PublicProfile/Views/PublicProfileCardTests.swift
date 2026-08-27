import XCTest
@testable import TheRecruitingCompass

final class PublicProfileCardTests: XCTestCase {
    nonisolated deinit {}

    func testAcademicsPairsWithValuesWhenBothVisible() {
        let rows = PublicProfileCard.pairedSections(for: [.academics, .values])
        XCTAssertEqual(rows, [PublicProfileCard.SectionRow(primary: .academics, paired: .values)])
    }

    func testValuesRendersStandaloneWhenAcademicsHidden() {
        let rows = PublicProfileCard.pairedSections(for: [.values])
        XCTAssertEqual(rows, [PublicProfileCard.SectionRow(primary: .values, paired: nil)])
    }

    func testTeamHistoryPairsWithAwardsWhenBothVisible() {
        let rows = PublicProfileCard.pairedSections(for: [.teamHistory, .awards])
        XCTAssertEqual(rows, [PublicProfileCard.SectionRow(primary: .teamHistory, paired: .awards)])
    }

    func testAwardsRendersStandaloneWhenTeamHistoryHidden() {
        let rows = PublicProfileCard.pairedSections(for: [.awards])
        XCTAssertEqual(rows, [PublicProfileCard.SectionRow(primary: .awards, paired: nil)])
    }

    func testFullDefaultOrderPairsBothRows() {
        let rows = PublicProfileCard.pairedSections(for: DefaultSectionOrder.keys)
        XCTAssertEqual(rows, [
            PublicProfileCard.SectionRow(primary: .metrics, paired: nil),
            PublicProfileCard.SectionRow(primary: .film, paired: nil),
            PublicProfileCard.SectionRow(primary: .academics, paired: .values),
            PublicProfileCard.SectionRow(primary: .teamHistory, paired: .awards)
        ])
    }

    func testHiddenSectionsAreAbsentFromOrder() {
        let rows = PublicProfileCard.pairedSections(for: [.metrics])
        XCTAssertEqual(rows, [PublicProfileCard.SectionRow(primary: .metrics, paired: nil)])
    }
}
