import SwiftUI

/// Charts, events, metrics, and at-a-glance summary. Extracted so SwiftUI can skip re-evaluating
/// this body when only other view model state (e.g. stats, quick tasks) changes.
struct DashboardChartsAndDataSection: View {
  let visibility: WidgetVisibility
  let interactionTrends: [InteractionTrend]
  let events: [FullEvent]
  let metrics: [PerformanceMetric]
  let schoolsWithOffersPercentage: String
  let avgCoachResponsivenessFormatted: String
  let avgCoachResponsivenessColor: Color
  let interactionsThisMonth: Int
  let daysUntilGraduationFormatted: String
  let isEmpty: Bool

  var body: some View {
    VStack(spacing: 16) {
      if visibility.interactionTrendChart && !interactionTrends.isEmpty {
        InteractionTrendsChart(trends: interactionTrends)
      }

      if visibility.eventsSummary && !events.isEmpty {
        UpcomingEventsWidget(events: events)
      }

      if visibility.recentActivity {
        RecentActivityWidget()
      }

      if visibility.performanceSummary && !metrics.isEmpty {
        PerformanceMetricsWidget(metrics: metrics)
      }

      if visibility.atAGlanceSummary && !isEmpty {
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
      visibility: .default,
      interactionTrends: [],
      events: [],
      metrics: [],
      schoolsWithOffersPercentage: "25%",
      avgCoachResponsivenessFormatted: "75%",
      avgCoachResponsivenessColor: Color.green,
      interactionsThisMonth: 4,
      daysUntilGraduationFormatted: "365",
      isEmpty: false
    )
    .padding()
  }
}
