import SwiftUI

/// Progress + reference zone: at-a-glance snapshot, recruiting calendar, performance metrics, and
/// the passive trend/activity feeds. Extracted so SwiftUI can skip re-evaluating this body when
/// only action-zone state (e.g. quick tasks) changes.
struct DashboardInsightsSection: View {
  let visibility: WidgetVisibility
  let interactionTrends: [InteractionTrend]
  let metrics: [PerformanceMetric]
  let schoolsWithOffersPercentage: String
  let interactionsThisMonth: Int
  let daysUntilGraduationFormatted: String
  let isEmpty: Bool
  let athleteSport: String?
  let athleteGender: String?
  let graduationYear: Int?

  var body: some View {
    VStack(spacing: 16) {
      if visibility.atAGlanceSummary && !isEmpty {
        AtAGlanceSummary(
          schoolsWithOffers: schoolsWithOffersPercentage,
          interactionsThisMonth: interactionsThisMonth,
          daysUntilGraduation: daysUntilGraduationFormatted
        )
      }

      if visibility.recruitingCalendar {
        RecruitingCalendarWidget(sport: athleteSport, gender: athleteGender, graduationYear: graduationYear)
      }

      if visibility.performanceSummary && !metrics.isEmpty {
        PerformanceMetricsWidget(metrics: metrics)
      }

      if visibility.interactionTrendChart && !interactionTrends.isEmpty {
        InteractionTrendsChart(trends: interactionTrends)
      }

      if visibility.recentActivity {
        RecentActivityWidget()
      }
    }
  }
}

#Preview {
  ScrollView {
    DashboardInsightsSection(
      visibility: .default,
      interactionTrends: [],
      metrics: [],
      schoolsWithOffersPercentage: "25%",
      interactionsThisMonth: 4,
      daysUntilGraduationFormatted: "365",
      isEmpty: false,
      athleteSport: "Baseball",
      athleteGender: "male",
      graduationYear: 2029
    )
    .padding()
  }
}
