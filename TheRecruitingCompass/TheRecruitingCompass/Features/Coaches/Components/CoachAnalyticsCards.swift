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
        title: "Head Coaches",
        value: analytics.headCoachCount,
        icon: "star.circle.fill",
        backgroundColor: Color.purple.opacity(0.1),
        iconColor: .purple,
        accessibilityLabelOverride: analytics.headCoachCount == 1
          ? "1 head coach"
          : "\(analytics.headCoachCount) head coaches"
      )

      AnalyticsCard(
        title: "Recent Contacts",
        value: analytics.recentContactsCount,
        icon: "bubble.left.circle.fill",
        backgroundColor: Color.green.opacity(0.1),
        iconColor: .green,
        accessibilityLabelOverride: analytics.recentContactsCount == 1
          ? "1 recent contact"
          : "\(analytics.recentContactsCount) recent contacts"
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
