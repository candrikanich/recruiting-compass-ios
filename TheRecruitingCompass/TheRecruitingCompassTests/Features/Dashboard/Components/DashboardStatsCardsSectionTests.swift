import SwiftUI
import XCTest
@testable import TheRecruitingCompass

final class DashboardStatsCardsSectionTests: XCTestCase {
  private let stats = DashboardStats(
    coachCount: 5, schoolCount: 12, interactionCount: 8,
    totalOffers: 3, acceptedOffers: 1, acceptanceRate: 0.33
  )

  func test_tiles_inOrder_carryTheirMetricAndAccent() {
    let tiles = DashboardStatsCardsSection.tiles(stats: stats, visibility: .default)
    XCTAssertEqual(tiles.map(\.title), ["Coaches", "Schools", "Interactions", "Events"])
    XCTAssertEqual(tiles.map(\.metric), [.coaches, .schools, .interactions, .events])
    XCTAssertEqual(tiles.map(\.metric.accent), [.forest, .forest, .gold, .gold])
  }

  func test_tiles_interactions_isGoldNotForest() {
    let tile = DashboardStatsCardsSection.tiles(stats: stats, visibility: .default)
      .first { $0.title == "Interactions" }
    XCTAssertEqual(tile?.metric.accent, .gold)
    XCTAssertEqual(tile?.count, 8)
  }

  func test_tiles_respectVisibility() {
    var visibility = StatsCardVisibility.default
    visibility.coaches = false
    visibility.events = false
    let tiles = DashboardStatsCardsSection.tiles(stats: stats, visibility: visibility)
    XCTAssertEqual(tiles.map(\.metric), [.schools, .interactions])
  }

  func test_header_stacksOnlyAtAccessibilitySizes() {
    XCTAssertFalse(StatCard.stacksHeader(for: .large))
    XCTAssertFalse(StatCard.stacksHeader(for: .xxxLarge))
    XCTAssertTrue(StatCard.stacksHeader(for: .accessibility1))
    XCTAssertTrue(StatCard.stacksHeader(for: .accessibility3))
  }
}
