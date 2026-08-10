//
//  MainTabView.swift
//  TheRecruitingCompass
//
//  Created by Claude Code on 2/12/26.
//
//  Uses 5 tabs to avoid iOS TabView "More" overflow double nav bar.
//  Overflow sections (Events, Documents, etc.) live in custom MoreMenuView.
//

import SwiftUI

struct MainTabView: View {
  @Environment(AuthManager.self) private var authManager
  @Environment(FamilyManager.self) private var familyManager
  @State private var notificationsViewModel = NotificationsListViewModel()
  @State private var dashboardViewModel = DashboardViewModel()
  @State private var selectedTab: AppTab = .dashboard
  @State private var schoolsPath = NavigationPath()
  @State private var coachesPath = NavigationPath()
  @State private var interactionsPath = NavigationPath()
  @State private var morePath: [MorePath] = []
  @Binding var pendingPushDestination: NotificationDestination?

  init(pendingPushDestination: Binding<NotificationDestination?> = .constant(nil)) {
    self._pendingPushDestination = pendingPushDestination
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      Tab("Dashboard", systemImage: "house", value: AppTab.dashboard) {
        NavigationStack {
          DashboardView(viewModel: dashboardViewModel)
            .activityNavigation()
            .navigationDestination(for: DashboardDestination.self) { destination in
              dashboardDestinationView(for: destination)
            }
        }
      }

      Tab("Schools", systemImage: "building.2", value: AppTab.schools) {
        SchoolsListView(navigationPath: $schoolsPath)
      }

      Tab("Coaches", systemImage: "person.2", value: AppTab.coaches) {
        CoachesListView(navigationPath: $coachesPath)
      }

      Tab("Interactions", systemImage: "bubble.left.and.bubble.right", value: AppTab.interactions) {
        InteractionsListView(navigationPath: $interactionsPath)
      }

      Tab("More", systemImage: "ellipsis.circle", value: AppTab.more) {
        MoreMenuView(notificationsViewModel: notificationsViewModel, path: $morePath)
      }
      .badge(notificationsViewModel.unreadCount > 0 ? notificationsViewModel.unreadCount : 0)
    }
    .environment(\.switchTab, { selectedTab = $0 })
    .environment(\.openMoreSection, { section in
      morePath = [.section(section)]
      selectedTab = .more
    })
    .task {
      await notificationsViewModel.fetchNotifications()
    }
    .onChange(of: pendingPushDestination) { _, destination in
      guard let destination else { return }
      pendingPushDestination = nil
      navigate(to: destination)
    }
  }

  private func navigate(to destination: NotificationDestination) {
    switch destination {
    case .schoolDetail(let id):
      var path = NavigationPath()
      path.append(SchoolDestination.detail(id))
      schoolsPath = path
      selectedTab = .schools
    case .coachDetail(let id):
      var path = NavigationPath()
      path.append(CoachDestination.detail(id))
      coachesPath = path
      selectedTab = .coaches
    case .interactionDetail(let id):
      var path = NavigationPath()
      path.append(InteractionDestination.detail(id))
      interactionsPath = path
      selectedTab = .interactions
    case .offerDetail(let id):
      morePath = [.section(.offers), .offerDetail(offerId: id)]
      selectedTab = .more
    case .eventDetail(let id):
      morePath = [.section(.events), .eventDetail(eventId: id)]
      selectedTab = .more
    }
  }

  @ViewBuilder
  private func dashboardDestinationView(for destination: DashboardDestination) -> some View {
    switch destination {
    case .coaches:
      CoachesListView()
    case .schools:
      SchoolsListView()
    case .interactions:
      InteractionsListView()
    case .offers:
      OffersListView()
    case .accepted:
      OffersListView()
    case .aTier:
      SchoolsListView()
    case .suggestions:
      SuggestionsListView(viewModel: dashboardViewModel)
    case .familyManagement:
      FamilyManagementView()
    }
  }
}

#Preview {
  MainTabView()
    .environment(AuthManager.shared)
    .environment(FamilyManager.shared)
}
