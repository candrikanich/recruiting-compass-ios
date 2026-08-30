// TheRecruitingCompass/TheRecruitingCompassTests/Shared/Components/Layout/AdaptiveDetailLayoutTests.swift
import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class AdaptiveDetailLayoutTests: XCTestCase {
    nonisolated deinit {}

    func testTrailingSidebarCompact() {
        let view = AdaptiveDetailLayout(sidebarPlacement: .trailing) {
            Text("Content")
        } sidebar: {
            Text("Sidebar")
        }
        .environment(\.horizontalSizeClass, .compact)

        XCTAssertNotNil(view)
    }

    func testTrailingSidebarRegular() {
        let view = AdaptiveDetailLayout(sidebarPlacement: .trailing) {
            Text("Content")
        } sidebar: {
            Text("Sidebar")
        }
        .environment(\.horizontalSizeClass, .regular)

        XCTAssertNotNil(view)
    }

    func testLeadingSidebarRegular() {
        let view = AdaptiveDetailLayout(sidebarPlacement: .leading) {
            Text("Content")
        } sidebar: {
            Text("Sidebar")
        }
        .environment(\.horizontalSizeClass, .regular)

        XCTAssertNotNil(view)
    }

    func testCustomSidebarWidth() {
        let view = AdaptiveDetailLayout(
            sidebarPlacement: .leading,
            sidebarWidth: 340
        ) {
            Text("Content")
        } sidebar: {
            Text("Sidebar")
        }
        .environment(\.horizontalSizeClass, .regular)

        XCTAssertNotNil(view)
    }
}
