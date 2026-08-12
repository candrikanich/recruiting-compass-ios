import SwiftUI

struct SchoolAnalyticsCards: View {
  let analytics: SchoolAnalytics

  var body: some View {
    LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
      ],
      spacing: 12
    ) {
      AnalyticsCard(
        title: "Total Schools",
        value: analytics.totalCount,
        icon: "building.2.fill",
        backgroundColor: Color.blue.opacity(0.1),
        iconColor: .blue,
        accessibilityLabelOverride: analytics.totalCount == 1
          ? "1 total school"
          : "\(analytics.totalCount) total schools"
      )

      AnalyticsCard(
        title: "Favorites",
        value: analytics.favoritesCount,
        icon: "star.circle.fill",
        backgroundColor: Color.orange.opacity(0.1),
        iconColor: .orange,
        accessibilityLabelOverride: analytics.favoritesCount == 1
          ? "1 favorite school"
          : "\(analytics.favoritesCount) favorite schools"
      )

      AnalyticsCard(
        title: "Visited",
        value: analytics.visitedCount,
        icon: "map.circle.fill",
        backgroundColor: Color.green.opacity(0.1),
        iconColor: .green,
        accessibilityLabelOverride: analytics.visitedCount == 1
          ? "1 school visited"
          : "\(analytics.visitedCount) schools visited"
      )

      AnalyticsCard(
        title: "Contacted",
        value: analytics.contactedCount,
        icon: "bubble.left.and.bubble.right.fill",
        backgroundColor: Color.purple.opacity(0.1),
        iconColor: .purple,
        accessibilityLabelOverride: analytics.contactedCount == 1
          ? "1 school contacted"
          : "\(analytics.contactedCount) schools contacted"
      )
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

#Preview {
  SchoolAnalyticsCards(
    analytics: SchoolAnalytics(
      totalCount: 35,
      favoritesCount: 8,
      visitedCount: 3,
      contactedCount: 12
    )
  )
  .padding()
  .background(Color(.systemGroupedBackground))
}
