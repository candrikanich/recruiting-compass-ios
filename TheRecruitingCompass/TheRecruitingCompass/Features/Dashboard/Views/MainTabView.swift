//
//  MainTabView.swift
//  TheRecruitingCompass
//
//  Created by Claude Code on 2/12/26.
//

import SwiftUI

struct MainTabView: View {
  @EnvironmentObject var authManager: AuthManager
  @EnvironmentObject var familyManager: FamilyManager
  @StateObject private var notificationsViewModel = NotificationsListViewModel()

  var body: some View {
    TabView {
      NavigationStack {
        DashboardView()
      }
      .tabItem {
        Label("Dashboard", systemImage: "house.fill")
      }
      .accessibilityLabel("Dashboard")

      NavigationStack {
        CoachesListView()
      }
      .tabItem {
        Label("Coaches", systemImage: "person.2.fill")
      }
      .accessibilityLabel("Coaches")

      NavigationStack {
        SchoolsListView()
      }
      .tabItem {
        Label("Schools", systemImage: "building.2.fill")
      }
      .accessibilityLabel("Schools")

      NavigationStack {
        InteractionsListView()
      }
      .tabItem {
        Label("Interactions", systemImage: "bubble.left.and.bubble.right.fill")
      }
      .accessibilityLabel("Interactions")

      NotificationsListView(viewModel: notificationsViewModel)
        .tabItem {
          Label("Notifications", systemImage: "bell.fill")
        }
        .badge(notificationsViewModel.unreadCount > 0 ? notificationsViewModel.unreadCount : 0)
        .accessibilityLabel("Notifications")

      NavigationStack {
        FamilyManagementView()
      }
      .tabItem {
        Label("Family", systemImage: "person.3.fill")
      }
      .accessibilityLabel("Family")
    }
  }
}

#Preview {
  MainTabView()
    .environmentObject(AuthManager.shared)
    .environmentObject(FamilyManager.shared)
}
