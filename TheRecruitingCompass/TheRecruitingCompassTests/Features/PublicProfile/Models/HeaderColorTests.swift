import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class HeaderColorTests: XCTestCase {
    nonisolated deinit {}

    func testAllEightKeysPresent() {
        XCTAssertEqual(
            Set(HeaderColor.allCases.map(\.rawValue)),
            ["slate", "blue", "emerald", "violet", "rose", "amber", "teal", "indigo"]
        )
    }

    func testFromUnknownDefaultsToSlate() {
        XCTAssertEqual(HeaderColor.from("chartreuse"), .slate)
        XCTAssertEqual(HeaderColor.from("blue"), .blue)
    }

    func testEveryCaseHasNonEmptyLabel() {
        for c in HeaderColor.allCases { XCTAssertFalse(c.label.isEmpty) }
    }
}
