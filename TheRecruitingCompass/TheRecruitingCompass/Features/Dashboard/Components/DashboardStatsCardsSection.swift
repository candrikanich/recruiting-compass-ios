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
            title: "Coaches",
            count: stats.coachCount,
            subtitle: nil,
            description: "View all coaches",
            icon: "person.2",
            gradientColors: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")],
            isEnabled: true,
            destination: .coaches
          )
        }
        .accessibilityLabel("View all coaches, \(stats.coachCount) total")
        .accessibilityHint("Opens your coaches list")
        .buttonStyle(PlainButtonStyle())
      }

      if visibility.schools {
        Button {
          switchTab(.schools)
        } label: {
          StatCard(
            title: "Schools",
            count: stats.schoolCount,
            subtitle: nil,
            description: "Manage schools",
            icon: "building.2",
            gradientColors: [Color(hex: "#8B5CF6"), Color(hex: "#7C3AED")],
            isEnabled: true,
            destination: .schools
          )
        }
        .accessibilityLabel("View all schools, \(stats.schoolCount) total")
        .accessibilityHint("Opens your schools list")
        .buttonStyle(PlainButtonStyle())
      }

      if visibility.interactions {
        Button {
          switchTab(.interactions)
        } label: {
          StatCard(
            title: "Interactions",
            count: stats.interactionCount,
            subtitle: nil,
            description: "Track interactions",
            icon: "bubble.left.and.bubble.right",
            gradientColors: [Color(hex: "#10B981"), Color(hex: "#059669")],
            isEnabled: true,
            destination: .interactions
          )
        }
        .accessibilityLabel("View all interactions, \(stats.interactionCount) total")
        .accessibilityHint("Opens your interactions list")
        .buttonStyle(PlainButtonStyle())
      }

      if visibility.offers {
        NavigationLink(value: DashboardDestination.offers) {
          StatCard(
            title: "Offers",
            count: stats.totalOffers,
            subtitle: nil,
            description: "View all offers",
            icon: "gift",
            gradientColors: [Color(hex: "#F97316"), Color(hex: "#EA580C")],
            isEnabled: true,
            destination: .offers
          )
        }
        .accessibilityLabel("View all offers, \(stats.totalOffers) total")
        .accessibilityHint("Opens your offers list")
        .buttonStyle(PlainButtonStyle())
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
      aTierSchoolCount: 4,
      acceptanceRate: 0.33
    ),
    visibility: .default
  )
  .padding()
}
