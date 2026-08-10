import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class PublicProfileComponentsTests: XCTestCase {
    nonisolated deinit {}

    func testColorPickerInitializesWithBinding() {
        var selection = HeaderColor.slate
        let binding = Binding(get: { selection }, set: { selection = $0 })
        _ = HeaderColorPicker(selection: binding)  // compiles + constructs
        XCTAssertEqual(selection, .slate)
    }

    func testShareLinkRowCopyInvokesCallback() {
        var copied = false
        let row = ShareLinkRow(
            url: URL(string: "https://x/p/abc"),
            onCopy: { copied = true }
        )
        row.onCopy()
        XCTAssertTrue(copied)
    }
}
