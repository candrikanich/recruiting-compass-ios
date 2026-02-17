import SwiftUI

/// Renders the dashboard stat cards grid. Extracted so SwiftUI can skip re-evaluating this body
/// when only other view model state (e.g. quick tasks, suggestions) changes.
struct DashboardStatsCardsSection: View {
  let stats: DashboardStats

  var body: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
      NavigationLink(value: DashboardDestination.coaches) {
        StatCard(
          title: "Coaches",
          count: stats.coachCount,
          subtitle: nil,
          icon: "person.2.fill",
          gradientColors: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")],
          isEnabled: true,
          destination: .coaches
        )
      }
      .accessibilityLabel("View all coaches, \(stats.coachCount) total")
      .accessibilityHint("Opens your coaches list")
      .buttonStyle(PlainButtonStyle())

      NavigationLink(value: DashboardDestination.schools) {
        StatCard(
          title: "Schools",
          count: stats.schoolCount,
          subtitle: nil,
          icon: "building.2.fill",
          gradientColors: [Color(hex: "#8B5CF6"), Color(hex: "#7C3AED")],
          isEnabled: true,
          destination: .schools
        )
      }
      .accessibilityLabel("View all schools, \(stats.schoolCount) total")
      .accessibilityHint("Opens your schools list")
      .buttonStyle(PlainButtonStyle())

      NavigationLink(value: DashboardDestination.interactions) {
        StatCard(
          title: "Interactions",
          count: stats.interactionCount,
          subtitle: nil,
          icon: "bubble.left.and.bubble.right.fill",
          gradientColors: [Color(hex: "#10B981"), Color(hex: "#059669")],
          isEnabled: true,
          destination: .interactions
        )
      }
      .accessibilityLabel("View all interactions, \(stats.interactionCount) total")
      .accessibilityHint("Opens your interactions list")
      .buttonStyle(PlainButtonStyle())

      NavigationLink(value: DashboardDestination.offers) {
        StatCard(
          title: "Offers",
          count: stats.totalOffers,
          subtitle: nil,
          icon: "gift.fill",
          gradientColors: [Color(hex: "#F97316"), Color(hex: "#EA580C")],
          isEnabled: true,
          destination: .offers
        )
      }
      .accessibilityLabel("View all offers, \(stats.totalOffers) total")
      .accessibilityHint("Opens your offers list")
      .buttonStyle(PlainButtonStyle())

      NavigationLink(value: DashboardDestination.accepted) {
        StatCard(
          title: "Accepted",
          count: stats.acceptedOffers,
          subtitle: stats.acceptanceRateFormatted,
          icon: "checkmark.circle.fill",
          gradientColors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
          isEnabled: true,
          destination: .accepted
        )
      }
      .accessibilityLabel("View accepted offers, \(stats.acceptedOffers) total")
      .accessibilityHint("Opens your accepted offers list")
      .buttonStyle(PlainButtonStyle())

      NavigationLink(value: DashboardDestination.aTier) {
        StatCard(
          title: "A-Tier",
          count: stats.aTierSchoolCount,
          subtitle: nil,
          icon: "star.fill",
          gradientColors: [Color(hex: "#6366F1"), Color(hex: "#4F46E5")],
          isEnabled: true,
          destination: .aTier
        )
      }
      .accessibilityLabel("View A-Tier schools, \(stats.aTierSchoolCount) total")
      .accessibilityHint("Opens your top-tier schools list")
      .buttonStyle(PlainButtonStyle())
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
    )
  )
  .padding()
}
