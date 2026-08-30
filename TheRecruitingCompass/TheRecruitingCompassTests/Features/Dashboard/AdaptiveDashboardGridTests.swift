import XCTest
@testable import TheRecruitingCompass

final class AdaptiveDashboardGridTests: XCTestCase {
    func testWidgetWidthClassification() {
        // Sidebar widgets
        XCTAssertEqual(DashboardWidgetID.recruitingCalendar.widthClass, .sidebar)

        // Full-width widgets
        XCTAssertEqual(DashboardWidgetID.actionItems.widthClass, .full)
        XCTAssertEqual(DashboardWidgetID.interactionTrends.widthClass, .full)

        // Half-width widgets
        XCTAssertEqual(DashboardWidgetID.coachFollowup.widthClass, .half)
        XCTAssertEqual(DashboardWidgetID.upcomingEvents.widthClass, .half)
    }

    func testMainWidgetsExcludesSidebar() {
        let allWidgets = DashboardWidgetID.allCases
        let mainWidgets = allWidgets.filter { $0.widthClass != .sidebar }
        let sidebarWidgets = allWidgets.filter { $0.widthClass == .sidebar }

        XCTAssertTrue(mainWidgets.count > sidebarWidgets.count)
        XCTAssertTrue(sidebarWidgets.count >= 1)
    }

    func testAllWidgetsHaveWidthClass() {
        for widget in DashboardWidgetID.allCases {
            // Should not crash — every case has a widthClass
            _ = widget.widthClass
        }
    }
}
