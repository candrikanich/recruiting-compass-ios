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
      NavigationStack {
        DashboardView(viewModel: dashboardViewModel)
          .activityNavigation()
          .navigationDestination(for: DashboardDestination.self) { destination in
            dashboardDestinationView(for: destination)
          }
      }
      .tabItem {
        Label {
          Text("Dashboard")
        } icon: {
          Image(systemName: "house")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .tag(AppTab.dashboard)
      .accessibilityLabel("Dashboard")

      SchoolsListView()
      .tabItem {
        Label {
          Text("Schools")
        } icon: {
          Image(systemName: "building.2")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .tag(AppTab.schools)
      .accessibilityLabel("Schools")

      CoachesListView()
      .tabItem {
        Label {
          Text("Coaches")
        } icon: {
          Image(systemName: "person.2")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .tag(AppTab.coaches)
      .accessibilityLabel("Coaches")

      InteractionsListView()
      .tabItem {
        Label {
          Text("Interactions")
        } icon: {
          Image(systemName: "bubble.left.and.bubble.right")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .tag(AppTab.interactions)
      .accessibilityLabel("Interactions")

      MoreMenuView(notificationsViewModel: notificationsViewModel)
      .tabItem {
        Label {
          Text("More")
        } icon: {
          Image(systemName: "ellipsis.circle")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .tag(AppTab.more)
      .badge(notificationsViewModel.unreadCount > 0 ? notificationsViewModel.unreadCount : 0)
      .accessibilityLabel("More")
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
