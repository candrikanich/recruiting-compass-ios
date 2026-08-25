import XCTest
@testable import TheRecruitingCompass

final class DashboardWidgetVisibilityTests: XCTestCase {
  nonisolated deinit {}

  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  // MARK: - Default

  func testDefault_UsesValueFirstOrder() {
    XCTAssertEqual(DashboardWidgetVisibility.default.widgetOrder, DashboardWidgetID.defaultOrder)
    XCTAssertEqual(DashboardWidgetID.defaultOrder.count, DashboardWidgetID.allCases.count)
  }

  // MARK: - Codable round-trip

  func testCodable_RoundTripPreservesOrder() throws {
    var value = DashboardWidgetVisibility.default
    value.widgetOrder = [.recentActivity, .actionItems, .performance, .coachFollowup,
                         .upcomingEvents, .quickTasks, .atAGlance, .recruitingCalendar,
                         .interactionTrends]

    let restored = try decoder.decode(DashboardWidgetVisibility.self,
                                      from: try encoder.encode(value))

    XCTAssertEqual(restored.widgetOrder, value.widgetOrder)
    XCTAssertEqual(restored, value)
  }

  // MARK: - Migration / normalization

  func testDecode_MissingWidgetOrder_FallsBackToDefault() throws {
    // Simulates a Phase-1 payload saved before widgetOrder existed.
    let json = """
    { "statsCards": \(try defaultStatsCardsJSON()), "widgets": \(try defaultWidgetsJSON()) }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(DashboardWidgetVisibility.self, from: json)

    XCTAssertEqual(decoded.widgetOrder, DashboardWidgetID.defaultOrder)
  }

  func testNormalizedOrder_PartialStored_AppendsMissingIds() {
    // Only two ids stored; the rest must be appended in default order, once each.
    let result = DashboardWidgetID.normalizedOrder(from: ["performance", "actionItems"])

    XCTAssertEqual(result.prefix(2), [.performance, .actionItems])
    XCTAssertEqual(Set(result), Set(DashboardWidgetID.allCases))
    XCTAssertEqual(result.count, DashboardWidgetID.allCases.count)
  }

  func testNormalizedOrder_UnknownAndDuplicateIds_AreDropped() {
    let result = DashboardWidgetID.normalizedOrder(
      from: ["actionItems", "bogusWidget", "actionItems", "coachFollowup"])

    // Unknown dropped, duplicate collapsed, remainder appended — still a complete, unique set.
    XCTAssertEqual(result.prefix(2), [.actionItems, .coachFollowup])
    XCTAssertEqual(result.count, DashboardWidgetID.allCases.count)
    XCTAssertEqual(Set(result).count, result.count)
  }

  // MARK: - Helpers

  private func defaultStatsCardsJSON() throws -> String {
    String(data: try encoder.encode(StatsCardVisibility.default), encoding: .utf8)!
  }

  private func defaultWidgetsJSON() throws -> String {
    String(data: try encoder.encode(WidgetVisibility.default), encoding: .utf8)!
  }
}
