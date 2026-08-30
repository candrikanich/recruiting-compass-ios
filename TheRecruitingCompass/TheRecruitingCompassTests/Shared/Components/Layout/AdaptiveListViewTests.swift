// TheRecruitingCompass/TheRecruitingCompassTests/Shared/Components/Layout/AdaptiveListViewTests.swift
import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class AdaptiveListViewTests: XCTestCase {
    nonisolated deinit {}

    struct MockItem: Identifiable {
        let id: Int
        let name: String
    }

    func testAdaptiveListViewCompactCreation() {
        let items = (1...10).map { MockItem(id: $0, name: "Item \($0)") }
        let view = AdaptiveListView(items: items) { item in
            Text(item.name)
        }
        .environment(\.horizontalSizeClass, .compact)

        XCTAssertNotNil(view)
    }

    func testAdaptiveListViewRegularCreation() {
        let items = (1...10).map { MockItem(id: $0, name: "Item \($0)") }
        let view = AdaptiveListView(items: items) { item in
            Text(item.name)
        }
        .environment(\.horizontalSizeClass, .regular)

        XCTAssertNotNil(view)
    }

    func testAdaptiveListViewEmptyItems() {
        let items: [MockItem] = []
        let view = AdaptiveListView(items: items) { item in
            Text(item.name)
        }
        XCTAssertNotNil(view)
    }
}
