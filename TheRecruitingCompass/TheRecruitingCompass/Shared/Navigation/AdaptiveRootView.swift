import SwiftUI

/// Top-level navigation shell: `TabView` on iPhone (compact width), `NavigationSplitView`
/// with a persistent sidebar on iPad (regular width). Replaces `MainTabView` at the app
/// entry point; iPhone behavior is unchanged since compact width just delegates to it.
struct AdaptiveRootView: View {
  @Binding var pendingPushDestination: NotificationDestination?
  @Environment(\.horizontalSizeClass) private var sizeClass
  @State private var selectedDestination: AppDestination? = .dashboard
  @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
  @State private var coachesPrefilterSchoolId: String?
  @State private var dashboardViewModel = DashboardViewModel()

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
    NavigationSplitView(columnVisibility: $columnVisibility) {
      SidebarView(selection: $selectedDestination)
    } detail: {
      detailView(for: selectedDestination ?? .dashboard)
    }
    .navigationSplitViewStyle(.prominentDetail)
    .background {
      keyboardShortcuts
    }
    .environment(\.switchTab, { selectedDestination = appDestination(for: $0) ?? selectedDestination })
    .environment(\.filterCoachesBySchool, { schoolId in
      coachesPrefilterSchoolId = schoolId
      selectedDestination = .coaches
    })
    .environment(\.openMoreSection, { section in
      selectedDestination = AppDestination(rawValue: section.rawValue) ?? selectedDestination
    })
    .onChange(of: selectedDestination) {
      // Auto-dismiss sidebar only when it's overlaying content (portrait / smaller iPads).
      // When pinned alongside detail (13" landscape), `.automatic` keeps it visible.
      if columnVisibility == .all {
        columnVisibility = .detailOnly
      }
    }
    .onChange(of: pendingPushDestination) { _, destination in
      guard let destination else { return }
      pendingPushDestination = nil
      selectedDestination = appDestination(for: destination)
    }
  }

  /// Hidden buttons carrying ⌘1-⌘6 (main sidebar sections) and ⌘, (settings) so the
  /// keyboard shortcuts register with the responder chain without a visible control.
  @ViewBuilder
  private var keyboardShortcuts: some View {
    let mainItems = AppDestination.allCases.filter { $0.section == .main }
    ForEach(Array(mainItems.enumerated()), id: \.element) { index, destination in
      Button("") { selectedDestination = destination }
        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
        .hidden()
    }
    Button("") { selectedDestination = .settings }
      .keyboardShortcut(",", modifiers: .command)
      .hidden()
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

  // Schools/Coaches/Interactions each own an internal `NavigationStack(path:)` already —
  // wrapping them again here would double-nest (broken push behavior, double nav bar).
  // Every other destination has no stack of its own, so it needs one from us.
  @ViewBuilder
  private func detailView(for destination: AppDestination) -> some View {
    switch destination {
    case .schools:
      SchoolsListView()
    case .coaches:
      CoachesListView(prefilterSchoolId: $coachesPrefilterSchoolId)
    case .interactions:
      InteractionsListView()
    default:
      NavigationStack {
        switch destination {
        case .dashboard:
          DashboardView(viewModel: dashboardViewModel)
            .activityNavigation()
            .navigationDestination(for: DashboardDestination.self) { dashboardDestination in
              dashboardDestinationView(for: dashboardDestination)
            }
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
        case .schools, .coaches, .interactions:
          EmptyView() // unreachable — handled above
        }
      }
    }
  }

  // .coaches/.schools/.interactions each own an internal `NavigationStack(path:)` already —
  // pushing them here (inside the dashboard's own NavigationStack) would double-nest. Instead,
  // switch the sidebar selection so the destination renders at the top level.
  @ViewBuilder
  private func dashboardDestinationView(for destination: DashboardDestination) -> some View {
    switch destination {
    case .coaches:
      Color.clear.onAppear { selectedDestination = .coaches }
    case .schools:
      Color.clear.onAppear { selectedDestination = .schools }
    case .interactions:
      Color.clear.onAppear { selectedDestination = .interactions }
    case .offers:
      OffersListView()
    case .accepted:
      OffersListView()
    case .aTier:
      Color.clear.onAppear { selectedDestination = .schools }
    case .suggestions:
      SuggestionsListView(viewModel: dashboardViewModel)
    case .familyManagement:
      FamilyManagementView()
    }
  }
}

#Preview {
  AdaptiveRootView()
    .environment(AuthManager.shared)
    .environment(FamilyManager.shared)
}
