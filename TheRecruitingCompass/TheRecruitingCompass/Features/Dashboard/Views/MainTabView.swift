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
        SchoolsListView()
      }

      Tab("Coaches", systemImage: "person.2", value: AppTab.coaches) {
        CoachesListView()
      }

      Tab("Interactions", systemImage: "bubble.left.and.bubble.right", value: AppTab.interactions) {
        InteractionsListView()
      }

      Tab("More", systemImage: "ellipsis.circle", value: AppTab.more) {
        MoreMenuView(notificationsViewModel: notificationsViewModel)
      }
      .badge(notificationsViewModel.unreadCount > 0 ? notificationsViewModel.unreadCount : 0)
    }
    .environment(\.switchTab, { selectedTab = $0 })
    .task {
      await notificationsViewModel.fetchNotifications()
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
