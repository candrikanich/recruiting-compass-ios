import SwiftUI

struct EventAnalyticsCards: View {
  let analytics: EventAnalytics

  var body: some View {
    LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
      ],
      spacing: 12
    ) {
      AnalyticsCard(
        title: "Total Events",
        value: analytics.totalCount,
        icon: "calendar.circle.fill",
        backgroundColor: Color.blue.opacity(0.1),
        iconColor: .blue,
        accessibilityLabelOverride: analytics.totalCount == 1
          ? "1 total event"
          : "\(analytics.totalCount) total events"
      )

      AnalyticsCard(
        title: "Upcoming",
        value: analytics.upcomingCount,
        icon: "arrow.right.circle.fill",
        backgroundColor: Color.purple.opacity(0.1),
        iconColor: .purple,
        accessibilityLabelOverride: analytics.upcomingCount == 1
          ? "1 upcoming event"
          : "\(analytics.upcomingCount) upcoming events"
      )

      AnalyticsCard(
        title: "Registered",
        value: analytics.registeredCount,
        icon: "checkmark.circle.fill",
        backgroundColor: Color.green.opacity(0.1),
        iconColor: .green,
        accessibilityLabelOverride: analytics.registeredCount == 1
          ? "1 registered event"
          : "\(analytics.registeredCount) registered events"
      )

      AnalyticsCard(
        title: "Attended",
        value: analytics.attendedCount,
        icon: "checkmark.seal.fill",
        backgroundColor: Color.orange.opacity(0.1),
        iconColor: .orange,
        accessibilityLabelOverride: analytics.attendedCount == 1
          ? "1 event attended"
          : "\(analytics.attendedCount) events attended"
      )
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

#Preview {
  EventAnalyticsCards(
    analytics: EventAnalytics(
      totalCount: 24,
      upcomingCount: 8,
      registeredCount: 5,
      attendedCount: 11
    )
  )
  .padding()
  .background(Color(.systemGroupedBackground))
}
