import SwiftUI

/// Renders the dashboard stat cards grid. Extracted so SwiftUI can skip re-evaluating this body
/// when only other view model state (e.g. quick tasks, suggestions) changes.
struct DashboardStatsCardsSection: View {
  let stats: DashboardStats
  let visibility: StatsCardVisibility
  @Environment(\.switchTab) private var switchTab

  var body: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
      if visibility.coaches {
        Button {
          switchTab(.coaches)
        } label: {
          StatCard(
            title: String(localized: "Coaches"),
            count: stats.coachCount,
            subtitle: nil,
            description: String(localized: "View all coaches"),
            icon: "person.2",
            gradientColors: [Color.Brand.blue600, Color.Brand.blue700],
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
            subtitle: nil,
            description: String(localized: "Manage schools"),
            icon: "building.2",
            gradientColors: [Color.Brand.purple600, Color.Brand.purple700],
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
            subtitle: nil,
            description: String(localized: "Track interactions"),
            icon: "bubble.left.and.bubble.right",
            gradientColors: [Color.Brand.emerald700, Color.Brand.emerald800],
            isEnabled: true,
            destination: .interactions
          )
        }
        .accessibilityLabel(String(localized: "View all interactions, \(stats.interactionCount) total"))
        .accessibilityHint("Opens your interactions list")
        .buttonStyle(.plain)
      }

      if visibility.offers {
        NavigationLink(value: DashboardDestination.offers) {
          StatCard(
            title: String(localized: "Offers"),
            count: stats.totalOffers,
            subtitle: nil,
            description: String(localized: "View all offers"),
            icon: "gift",
            gradientColors: [Color.Brand.orange700, Color.Brand.orange800],
            isEnabled: true,
            destination: .offers
          )
        }
        .accessibilityLabel(String(localized: "View all offers, \(stats.totalOffers) total"))
        .accessibilityHint("Opens your offers list")
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
