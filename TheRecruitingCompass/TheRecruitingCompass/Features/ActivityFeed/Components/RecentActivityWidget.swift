import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "ActivityFeed")

struct RecentActivityWidget: View {
  @State private var viewModel = ActivityFeedViewModel()
  @State private var realtimeService: ActivityRealtimeService?
  @State private var backgroundCleanupTask: Task<Void, Never>?
  @Environment(\.scenePhase) private var scenePhase
  @Environment(FamilyManager.self) private var familyManager

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
            .foregroundStyle(Color.accentBlue)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(refreshAccessibilityLabel)
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
          .foregroundStyle(Color.secondaryText)
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
              .font(.caption)
              .accessibilityHidden(true)
          }
          .foregroundStyle(Color.accentBlue)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(viewAllAccessibilityLabel)
        .accessibilityHint(viewAllAccessibilityHint)
        .accessibilityIdentifier("recent-activity-view-all")
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
    .accessibilityIdentifier("recent-activity-widget")
    .task {
      await loadAndSubscribe()
    }
    .onDisappear {
      backgroundCleanupTask?.cancel()
      let service = realtimeService
      realtimeService = nil
      Task {
        await service?.unsubscribe()
      }
    }
    .onChange(of: scenePhase) { _, newValue in
      if newValue == .active {
        backgroundCleanupTask?.cancel()
        Task {
          await loadAndSubscribe()
        }
      } else if newValue == .background {
        backgroundCleanupTask?.cancel()
        let service = realtimeService
        realtimeService = nil
        backgroundCleanupTask = Task {
          await service?.unsubscribe()
        }
      }
    }
  }

  // MARK: - Accessibility

  var refreshAccessibilityLabel: String { String(localized: "Refresh activities") }
  var viewAllAccessibilityLabel: String { String(localized: "View all activity") }
  var viewAllAccessibilityHint: String { "Opens the full activity history page" }

  // MARK: - Private Methods

  private func loadAndSubscribe() async {
    // Load initial activities
    await viewModel.loadActivities()

    // Subscribe to realtime updates
    guard let userId = viewModel.userId else { return }

    // Avoid re-subscribing when a live subscription already exists. `.task` and
    // the scenePhase `.active` transition can both fire on appear; a second
    // subscribe would reuse the already-joined channel topic and register a
    // postgresChange listener after the join (a no-op that logs a warning) while
    // leaking the overwritten service.
    guard realtimeService == nil else { return }

    let service = ActivityRealtimeService(supabaseManager: .shared)
    realtimeService = service

    do {
      try await service.subscribe(
        userId: userId,
        familyUnitId: familyManager.familyUnitId,
        onInsert: { [viewModel] newEvent in
          viewModel.addRealtimeEvent(newEvent)
        },
        onChange: { [viewModel] in
          Task { await viewModel.loadActivities() }
        }
      )
    } catch {
      // Log error but don't fail - widget still works without realtime
      logger.error("Failed to subscribe to realtime updates: \(error.localizedDescription)")
    }
  }
}

#Preview {
  NavigationStack {
    RecentActivityWidget()
      .padding()
  }
}
