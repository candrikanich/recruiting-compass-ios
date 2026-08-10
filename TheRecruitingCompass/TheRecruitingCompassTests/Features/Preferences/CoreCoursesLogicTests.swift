import XCTest
@testable import TheRecruitingCompass

final class CoreCoursesLogicTests: XCTestCase {
    func testTrimsAndAdds() {
        XCTAssertEqual(CoreCoursesEditor.normalizedToAdd("  AP Chem  ", existing: []), "AP Chem")
    }
    func testRejectsBlank() {
        XCTAssertNil(CoreCoursesEditor.normalizedToAdd("   ", existing: []))
    }
    func testRejectsDuplicate() {
        XCTAssertNil(CoreCoursesEditor.normalizedToAdd("AP Chem", existing: ["AP Chem"]))
    }
    func testRejectsAtCap() {
        let full = (1...20).map { "Course \($0)" }
        XCTAssertNil(CoreCoursesEditor.normalizedToAdd("Extra", existing: full))
    }
    func testTruncatesToSixtyChars() {
        let long = String(repeating: "x", count: 80)
        XCTAssertEqual(CoreCoursesEditor.normalizedToAdd(long, existing: [])?.count, 60)
    }
}
