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

  var body: some View {
    TabView {
      NavigationStack {
        DashboardView()
          .activityNavigation()
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
      .accessibilityLabel("Dashboard")

      NavigationStack {
        SchoolsListView()
      }
      .tabItem {
        Label {
          Text("Schools")
        } icon: {
          Image(systemName: "building.2")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .accessibilityLabel("Schools")

      NavigationStack {
        CoachesListView()
      }
      .tabItem {
        Label {
          Text("Coaches")
        } icon: {
          Image(systemName: "person.2")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .accessibilityLabel("Coaches")

      NavigationStack {
        InteractionsListView()
      }
      .tabItem {
        Label {
          Text("Interactions")
        } icon: {
          Image(systemName: "bubble.left.and.bubble.right")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
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
      .badge(notificationsViewModel.unreadCount > 0 ? notificationsViewModel.unreadCount : 0)
      .accessibilityLabel("More")
    }
    .task {
      await notificationsViewModel.fetchNotifications()
    }
  }
}

#Preview {
  MainTabView()
    .environment(AuthManager.shared)
    .environment(FamilyManager.shared)
}
