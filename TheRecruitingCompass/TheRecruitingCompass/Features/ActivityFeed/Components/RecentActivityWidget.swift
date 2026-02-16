import SwiftUI

struct RecentActivityWidget: View {
  @State private var viewModel = ActivityFeedViewModel()
  @State private var realtimeService: ActivityRealtimeService?
  @Environment(\.scenePhase) private var scenePhase

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
    .task {
      await loadAndSubscribe()
    }
    .onDisappear {
      Task {
        await realtimeService?.unsubscribe()
        realtimeService = nil
      }
    }
    .onChange(of: scenePhase) {
      if scenePhase == .active {
        Task {
          await loadAndSubscribe()
        }
      } else if scenePhase == .background {
        Task {
          await realtimeService?.unsubscribe()
        }
      }
    }
  }

  // MARK: - Private Methods

  private func loadAndSubscribe() async {
    // Load initial activities
    await viewModel.loadActivities()

    // Subscribe to realtime updates
    guard let userId = viewModel.userId else { return }

    let service = ActivityRealtimeService()
    realtimeService = service

    do {
      try await service.subscribe(userId: userId) { [viewModel] newEvent in
        viewModel.addRealtimeEvent(newEvent)
      }
    } catch {
      // Log error but don't fail - widget still works without realtime
      print("Failed to subscribe to realtime updates: \(error.localizedDescription)")
    }
  }
}

#Preview {
  NavigationStack {
    RecentActivityWidget()
      .padding()
  }
}
