import XCTest
@testable import TheRecruitingCompass

final class PublicProfileCardTests: XCTestCase {
    nonisolated deinit {}

    func testVisibleSectionsReflectNilData() {
        let data = PublicProfileData(
            playerName: "Jordan", photoUrl: nil, headerColor: .slate, bio: nil,
            academics: nil,
            athletic: .init(primarySport: "Baseball", primaryPosition: "SS",
                            positions: ["SS"], heightInches: 72, weightLbs: 180,
                            ncaaId: nil, perfectGameId: nil, prepBaseballId: nil),
            film: nil, schools: nil
        )
        let sections = PublicProfileCard.visibleSections(for: data)
        XCTAssertTrue(sections.contains(.athletic))
        XCTAssertFalse(sections.contains(.academics))
        XCTAssertFalse(sections.contains(.film))
        XCTAssertFalse(sections.contains(.schools))
    }

    func testVisibleSectionsIncludesAllWhenPopulated() {
        let data = PublicProfileData(
            playerName: "Riley", photoUrl: nil, headerColor: .blue, bio: "Bio",
            academics: .init(gpa: 3.8, satScore: 1400, actScore: nil,
                              graduationYear: 2027, highSchool: "Central HS", coreCourses: nil),
            athletic: .init(primarySport: "Baseball", primaryPosition: "SS",
                            positions: ["SS", "2B"], heightInches: 72, weightLbs: 180,
                            ncaaId: "123", perfectGameId: nil, prepBaseballId: nil),
            film: [.init(title: "Highlights", url: "https://example.com/video")],
            schools: [.init(id: "1", name: "State University")]
        )
        let sections = PublicProfileCard.visibleSections(for: data)
        XCTAssertEqual(sections, Set(PublicProfileCard.Section.allCases))
    }
}
