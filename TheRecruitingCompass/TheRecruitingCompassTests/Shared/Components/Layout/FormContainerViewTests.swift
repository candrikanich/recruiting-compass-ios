import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class FormContainerViewTests: XCTestCase {
    nonisolated deinit {}

    func testFormContainerCompact() {
        let view = FormContainerView {
            Text("Form field")
        }
        .environment(\.horizontalSizeClass, .compact)

        XCTAssertNotNil(view)
    }

    func testFormContainerRegular() {
        let view = FormContainerView {
            Text("Form field")
        }
        .environment(\.horizontalSizeClass, .regular)

        XCTAssertNotNil(view)
    }

    func testFormContainerCustomMaxWidth() {
        let view = FormContainerView(maxWidth: 800) {
            Text("Form field")
        }
        .environment(\.horizontalSizeClass, .regular)

        XCTAssertNotNil(view)
    }
}
