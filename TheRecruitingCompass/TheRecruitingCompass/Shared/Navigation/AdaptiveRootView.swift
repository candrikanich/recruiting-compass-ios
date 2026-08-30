import SwiftUI

/// Top-level navigation shell: `TabView` on iPhone (compact width), `NavigationSplitView`
/// with a persistent sidebar on iPad (regular width). Replaces `MainTabView` at the app
/// entry point; iPhone behavior is unchanged since compact width just delegates to it.
struct AdaptiveRootView: View {
  @Binding var pendingPushDestination: NotificationDestination?
  @Environment(\.horizontalSizeClass) private var sizeClass
  @State private var selectedDestination: AppDestination? = .dashboard
  @State private var coachesPrefilterSchoolId: String?
  @State private var dashboardViewModel = DashboardViewModel()
  @State private var notificationsViewModel = NotificationsListViewModel()

  init(pendingPushDestination: Binding<NotificationDestination?> = .constant(nil)) {
    self._pendingPushDestination = pendingPushDestination
  }

  var body: some View {
    if sizeClass == .regular {
      iPadLayout
    } else {
      MainTabView(pendingPushDestination: $pendingPushDestination)
    }
  }

  @ViewBuilder
  private var iPadLayout: some View {
    NavigationSplitView {
      SidebarView(selection: $selectedDestination)
    } detail: {
      detailView(for: selectedDestination ?? .dashboard)
    }
    .navigationSplitViewStyle(.balanced)
    .environment(\.switchTab, { selectedDestination = appDestination(for: $0) ?? selectedDestination })
    .environment(\.filterCoachesBySchool, { schoolId in
      coachesPrefilterSchoolId = schoolId
      selectedDestination = .coaches
    })
    .environment(\.openMoreSection, { section in
      selectedDestination = AppDestination(rawValue: section.rawValue) ?? selectedDestination
    })
    .task {
      await notificationsViewModel.fetchNotifications()
    }
    .onChange(of: pendingPushDestination) { _, destination in
      guard let destination else { return }
      pendingPushDestination = nil
      selectedDestination = appDestination(for: destination)
    }
  }

  private func appDestination(for tab: AppTab) -> AppDestination? {
    switch tab {
    case .dashboard: return .dashboard
    case .schools: return .schools
    case .coaches: return .coaches
    case .interactions: return .interactions
    case .more: return nil
    }
  }

  private func appDestination(for notification: NotificationDestination) -> AppDestination {
    switch notification {
    case .schoolDetail: return .schools
    case .coachDetail: return .coaches
    case .interactionDetail: return .interactions
    case .offerDetail: return .offers
    case .eventDetail: return .events
    }
  }

  @ViewBuilder
  private func detailView(for destination: AppDestination) -> some View {
    NavigationStack {
      switch destination {
      case .dashboard:
        DashboardView(viewModel: dashboardViewModel)
          .activityNavigation()
      case .schools:
        SchoolsListView()
      case .coaches:
        CoachesListView(prefilterSchoolId: $coachesPrefilterSchoolId)
      case .interactions:
        InteractionsListView()
      case .timeline:
        RecruitingTimelineView()
      case .events:
        EventsListView()
      case .performance:
        PerformanceDashboardView()
      case .offers:
        OffersListView()
      case .analytics:
        AnalyticsDashboardView()
      case .documents:
        DocumentsListView()
      case .deadlines:
        // No dedicated deadlines screen exists yet; deadlines surface inside the
        // recruiting timeline (see `TaskDeadlineCalculator`). Revisit if one is added.
        RecruitingTimelineView()
      case .settings:
        SettingsView()
      }
    }
  }
}

#Preview {
  AdaptiveRootView()
    .environment(AuthManager.shared)
    .environment(FamilyManager.shared)
}
