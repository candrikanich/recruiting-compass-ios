import XCTest
@testable import TheRecruitingCompass

final class SlugValidatorTests: XCTestCase {
    nonisolated deinit {}

    func testEmptyIsEmpty() {
        XCTAssertEqual(SlugValidator.validate(""), .empty)
    }
    func testValidSlug() {
        XCTAssertEqual(SlugValidator.validate("jordan-rivera-9"), .valid)
    }
    func testUppercaseIsInvalid() {
        XCTAssertEqual(SlugValidator.validate("Jordan"), .invalidFormat)
    }
    func testLeadingHyphenInvalid() {
        XCTAssertEqual(SlugValidator.validate("-jordan"), .invalidFormat)
    }
    func testTooLongInvalid() {
        XCTAssertEqual(SlugValidator.validate(String(repeating: "a", count: 31)), .invalidFormat)
    }
    func testReservedWord() {
        XCTAssertEqual(SlugValidator.validate("admin"), .reserved)
        XCTAssertEqual(SlugValidator.validate("coaches"), .reserved)
    }
}
