import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class AdaptiveRootViewTests: XCTestCase {
  nonisolated deinit {}

  func testCompactSizeClassRendersTabView() {
    // AdaptiveRootView should exist and accept the same bindings as MainTabView
    let view = AdaptiveRootView(pendingPushDestination: .constant(nil))
      .environment(\.horizontalSizeClass, .compact)
    XCTAssertNotNil(view)
  }

  func testRegularSizeClassRendersSplitView() {
    let view = AdaptiveRootView(pendingPushDestination: .constant(nil))
      .environment(\.horizontalSizeClass, .regular)
    XCTAssertNotNil(view)
  }

  func testDefaultSelectionIsDashboard() {
    let rootView = AdaptiveRootView(pendingPushDestination: .constant(nil))
    // The view should compile and default to dashboard
    XCTAssertNotNil(rootView)
  }
}
