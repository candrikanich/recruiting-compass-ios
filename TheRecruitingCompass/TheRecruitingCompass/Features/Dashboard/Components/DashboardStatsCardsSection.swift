import SwiftUI

/// Renders the dashboard stat cards grid. Extracted so SwiftUI can skip re-evaluating this body
/// when only other view model state (e.g. quick tasks, suggestions) changes.
struct DashboardStatsCardsSection: View {
  let stats: DashboardStats
  let visibility: StatsCardVisibility
  @Environment(\.switchTab) private var switchTab
  @Environment(\.openMoreSection) private var openMoreSection

  var body: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
      if visibility.coaches {
        Button {
          switchTab(.coaches)
        } label: {
          StatCard(
            title: String(localized: "Coaches"),
            count: stats.coachCount,
            icon: "person.2",
            isEnabled: true,
            destination: .coaches
          )
        }
        .accessibilityLabel(String(localized: "View all coaches, \(stats.coachCount) total"))
        .accessibilityHint("Opens your coaches list")
        .buttonStyle(.plain)
      }

      if visibility.schools {
        Button {
          switchTab(.schools)
        } label: {
          StatCard(
            title: String(localized: "Schools"),
            count: stats.schoolCount,
            icon: "building.2",
            isEnabled: true,
            destination: .schools
          )
        }
        .accessibilityLabel(String(localized: "View all schools, \(stats.schoolCount) total"))
        .accessibilityHint("Opens your schools list")
        .buttonStyle(.plain)
      }

      if visibility.interactions {
        Button {
          switchTab(.interactions)
        } label: {
          StatCard(
            title: String(localized: "Interactions"),
            count: stats.interactionCount,
            icon: "bubble.left.and.bubble.right",
            isEnabled: true,
            destination: .interactions
          )
        }
        .accessibilityLabel(String(localized: "View all interactions, \(stats.interactionCount) total"))
        .accessibilityHint("Opens your interactions list")
        .buttonStyle(.plain)
      }

      if visibility.events {
        Button {
          openMoreSection(.events)
        } label: {
          StatCard(
            title: String(localized: "Events"),
            count: stats.upcomingEventCount,
            icon: "calendar",
            isEnabled: true,
            destination: nil
          )
        }
        .accessibilityLabel(String(localized: "View events, \(stats.upcomingEventCount) upcoming"))
        .accessibilityHint("Opens your events list")
        .buttonStyle(.plain)
      }
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
