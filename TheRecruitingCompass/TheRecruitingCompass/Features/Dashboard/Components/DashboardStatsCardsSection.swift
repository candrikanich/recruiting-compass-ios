import SwiftUI

/// One visible stat tile. Order and metric are data so the accent wiring is testable.
struct DashboardStatTile: Equatable {
  let metric: StatMetric
  let title: String
  let count: Int
  let icon: String
  let accessibilityLabel: String
  let accessibilityHint: String
}

/// Renders the dashboard stat cards grid. Extracted so SwiftUI can skip re-evaluating this body
/// when only other view model state (e.g. quick tasks, suggestions) changes.
struct DashboardStatsCardsSection: View {
  let stats: DashboardStats
  let visibility: StatsCardVisibility
  @Environment(\.switchTab) private var switchTab
  @Environment(\.openMoreSection) private var openMoreSection

  static func tiles(stats: DashboardStats, visibility: StatsCardVisibility) -> [DashboardStatTile] {
    var tiles: [DashboardStatTile] = []
    if visibility.coaches {
      tiles.append(DashboardStatTile(
        metric: .coaches, title: String(localized: "Coaches"), count: stats.coachCount, icon: "person.2",
        accessibilityLabel: String(localized: "View all coaches, \(stats.coachCount) total"),
        accessibilityHint: String(localized: "Opens your coaches list")))
    }
    if visibility.schools {
      tiles.append(DashboardStatTile(
        metric: .schools, title: String(localized: "Schools"), count: stats.schoolCount, icon: "building.2",
        accessibilityLabel: String(localized: "View all schools, \(stats.schoolCount) total"),
        accessibilityHint: String(localized: "Opens your schools list")))
    }
    if visibility.interactions {
      tiles.append(DashboardStatTile(
        metric: .interactions, title: String(localized: "Interactions"), count: stats.interactionCount,
        icon: "bubble.left.and.bubble.right",
        accessibilityLabel: String(localized: "View all interactions, \(stats.interactionCount) total"),
        accessibilityHint: String(localized: "Opens your interactions list")))
    }
    if visibility.events {
      tiles.append(DashboardStatTile(
        metric: .events, title: String(localized: "Events"), count: stats.upcomingEventCount, icon: "calendar",
        accessibilityLabel: String(localized: "View events, \(stats.upcomingEventCount) upcoming"),
        accessibilityHint: String(localized: "Opens your events list")))
    }
    return tiles
  }

  var body: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
      ForEach(Self.tiles(stats: stats, visibility: visibility), id: \.metric) { tile in
        Button {
          open(tile.metric)
        } label: {
          StatCard(
            title: tile.title,
            count: tile.count,
            icon: tile.icon,
            metric: tile.metric,
            isEnabled: true,
            destination: nil
          )
        }
        .accessibilityLabel(tile.accessibilityLabel)
        .accessibilityHint(tile.accessibilityHint)
        .buttonStyle(.plain)
      }
    }
  }

  private func open(_ metric: StatMetric) {
    switch metric {
    case .coaches: switchTab(.coaches)
    case .schools: switchTab(.schools)
    case .interactions: switchTab(.interactions)
    case .events: openMoreSection(.events)
    }
  }
}

#Preview {
  DashboardStatsCardsSection(
    stats: DashboardStats(
      coachCount: 5,
      schoolCount: 12,
      interactionCount: 8,
      totalOffers: 3,
      acceptedOffers: 1,
      acceptanceRate: 0.33
    ),
    visibility: .default
  )
  .padding()
}
