import SwiftUI

struct InteractionAnalyticsCards: View {
  let analytics: InteractionAnalytics

  var body: some View {
    LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
      ],
      spacing: 12
    ) {
      AnalyticsCard(
        title: "Total",
        value: analytics.totalCount,
        icon: "bubble.left.and.bubble.right.fill",
        backgroundColor: Color.blue.opacity(0.1),
        iconColor: .blue
      )

      AnalyticsCard(
        title: "Outbound",
        value: analytics.outboundCount,
        icon: "arrow.up.circle.fill",
        backgroundColor: Color.green.opacity(0.1),
        iconColor: .green
      )

      AnalyticsCard(
        title: "Inbound",
        value: analytics.inboundCount,
        icon: "arrow.down.circle.fill",
        backgroundColor: Color.purple.opacity(0.1),
        iconColor: .purple
      )

      AnalyticsCard(
        title: "This Week",
        value: analytics.thisWeekCount,
        icon: "calendar.circle.fill",
        backgroundColor: Color.orange.opacity(0.1),
        iconColor: .orange
      )
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

#Preview {
  InteractionAnalyticsCards(
    analytics: InteractionAnalytics(
      totalCount: 47,
      outboundCount: 32,
      inboundCount: 15,
      thisWeekCount: 8
    )
  )
  .padding()
  .background(Color(.systemGroupedBackground))
}
