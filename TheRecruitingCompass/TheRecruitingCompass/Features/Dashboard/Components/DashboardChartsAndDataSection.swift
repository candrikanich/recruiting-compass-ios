import SwiftUI

/// Charts, events, metrics, and at-a-glance summary. Extracted so SwiftUI can skip re-evaluating
/// this body when only other view model state (e.g. stats, quick tasks) changes.
struct DashboardChartsAndDataSection: View {
  let interactionTrends: [InteractionTrend]
  let events: [Event]
  let metrics: [PerformanceMetric]
  let schoolsWithOffersPercentage: String
  let avgCoachResponsivenessFormatted: String
  let avgCoachResponsivenessColor: Color
  let interactionsThisMonth: Int
  let daysUntilGraduationFormatted: String
  let isEmpty: Bool

  var body: some View {
    VStack(spacing: 16) {
      if !interactionTrends.isEmpty {
        InteractionTrendsChart(trends: interactionTrends)
      }

      if !events.isEmpty {
        UpcomingEventsWidget(events: events)
      }

      RecentActivityWidget()

      if !metrics.isEmpty {
        PerformanceMetricsWidget(metrics: metrics)
      }

      if !isEmpty {
        AtAGlanceSummary(
          schoolsWithOffers: schoolsWithOffersPercentage,
          avgCoachResponsiveness: avgCoachResponsivenessFormatted,
          avgResponsivenessColor: avgCoachResponsivenessColor,
          interactionsThisMonth: interactionsThisMonth,
          daysUntilGraduation: daysUntilGraduationFormatted
        )
      }
    }
  }
}

#Preview {
  ScrollView {
    DashboardChartsAndDataSection(
      interactionTrends: [],
      events: [],
      metrics: [],
      schoolsWithOffersPercentage: "25%",
      avgCoachResponsivenessFormatted: "75%",
      avgCoachResponsivenessColor: .green,
      interactionsThisMonth: 4,
      daysUntilGraduationFormatted: "365",
      isEmpty: false
    )
    .padding()
  }
}
