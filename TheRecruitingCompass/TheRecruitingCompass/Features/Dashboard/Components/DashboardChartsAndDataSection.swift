import SwiftUI

/// Charts, events, metrics, and at-a-glance summary. Extracted so SwiftUI can skip re-evaluating
/// this body when only other view model state (e.g. stats, quick tasks) changes.
struct DashboardChartsAndDataSection: View {
  let visibility: WidgetVisibility
  let interactionTrends: [InteractionTrend]
  let events: [FullEvent]
  let coachesNeedingFollowup: [Coach]
  let allSchools: [School]
  let metrics: [PerformanceMetric]
  let schoolsWithOffersPercentage: String
  let interactionsThisMonth: Int
  let daysUntilGraduationFormatted: String
  let isEmpty: Bool
  let athleteSport: String?
  let athleteGender: String?
  /// Reload the dashboard after a coach send (follow-up list refresh).
  var onCoachContacted: (() -> Void)?

  var body: some View {
    VStack(spacing: 16) {
      if visibility.interactionTrendChart && !interactionTrends.isEmpty {
        InteractionTrendsChart(trends: interactionTrends)
      }

      if visibility.recruitingCalendar {
        RecruitingCalendarWidget(sport: athleteSport, gender: athleteGender)
      }

      if visibility.eventsSummary && !events.isEmpty {
        UpcomingEventsWidget(events: events)
      }

      if visibility.coachFollowupWidget && !coachesNeedingFollowup.isEmpty {
        CoachFollowupWidget(coaches: coachesNeedingFollowup, schools: allSchools,
                            onCoachContacted: onCoachContacted)
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
      coachesNeedingFollowup: [],
      allSchools: [],
      metrics: [],
      schoolsWithOffersPercentage: "25%",
      interactionsThisMonth: 4,
      daysUntilGraduationFormatted: "365",
      isEmpty: false,
      athleteSport: "Baseball",
      athleteGender: "male"
    )
    .padding()
  }
}
