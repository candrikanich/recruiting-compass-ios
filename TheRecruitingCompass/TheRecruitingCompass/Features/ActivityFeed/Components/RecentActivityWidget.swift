import SwiftUI

struct RecentActivityWidget: View {
  @State private var viewModel = ActivityFeedViewModel()

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      HStack {
        Text("Recent Activity")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        Spacer()

        Button {
          Task { await viewModel.loadActivities() }
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.subheadline)
            .foregroundColor(.accentBlue)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Refresh activities")
        .accessibilityIdentifier("recent-activity-refresh")
      }

      Divider()

      if viewModel.isLoading && viewModel.activities.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 16)
      } else if viewModel.recentActivities.isEmpty {
        Text("No recent activity")
          .font(.caption)
          .foregroundColor(.secondaryText)
          .padding(.vertical, 16)
      } else {
        VStack(spacing: 8) {
          ForEach(viewModel.recentActivities) { event in
            if event.isClickable {
              NavigationLink(value: ActivityDestination(event: event)) {
                ActivityEventItem(event: event, compact: true)
              }
              .buttonStyle(.plain)
            } else {
              ActivityEventItem(event: event, compact: true)
            }
          }
        }

        // "View All" link
        NavigationLink(value: ActivityFeedDestination.fullPage) {
          HStack(spacing: 4) {
            Text("View All Activity")
              .font(.caption)
            Image(systemName: "chevron.right")
              .font(.caption2)
              .accessibilityHidden(true)
          }
          .foregroundColor(.accentBlue)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("View all activity")
        .accessibilityHint("Opens the full activity history page")
        .accessibilityIdentifier("recent-activity-view-all")
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    .accessibilityIdentifier("recent-activity-widget")
    .task { await viewModel.loadActivities() }
  }
}

#Preview {
  NavigationStack {
    RecentActivityWidget()
      .padding()
  }
}
