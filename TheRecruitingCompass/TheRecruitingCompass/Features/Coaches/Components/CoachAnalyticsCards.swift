import SwiftUI

struct CoachAnalyticsCards: View {
  let analytics: CoachAnalytics

  var body: some View {
    LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
      ],
      spacing: 12
    ) {
      AnalyticsCard(
        title: "Total Coaches",
        value: analytics.totalCount,
        icon: "person.2.fill",
        backgroundColor: Color.blue.opacity(0.1),
        iconColor: .blue,
        accessibilityLabelOverride: analytics.totalCount == 1
          ? "1 total coach"
          : "\(analytics.totalCount) total coaches"
      )

      AnalyticsCard(
        title: "Need Follow-up",
        value: analytics.needFollowUpCount,
        icon: "clock.circle.fill",
        backgroundColor: Color.orange.opacity(0.1),
        iconColor: .orange,
        accessibilityLabelOverride: analytics.needFollowUpCount == 1
          ? "1 coach needs follow-up"
          : "\(analytics.needFollowUpCount) coaches need follow-up"
      )
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

#Preview {
  CoachAnalyticsCards(
    analytics: CoachAnalytics(
      totalCount: 24,
      headCoachCount: 8,
      recentContactsCount: 5,
      needFollowUpCount: 6
    )
  )
  .padding()
  .background(Color(.systemGroupedBackground))
}
