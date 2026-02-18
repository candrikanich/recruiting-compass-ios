//
//  MainTabView.swift
//  TheRecruitingCompass
//
//  Created by Claude Code on 2/12/26.
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
        EventsListView()
      }
      .tabItem {
        Label("Events", systemImage: "calendar")
      }
      .accessibilityLabel("Events")

      NavigationStack {
        DocumentsListView()
      }
      .tabItem {
        Label("Documents", systemImage: "doc.fill")
      }
      .accessibilityLabel("Documents")

      NavigationStack {
        InteractionsListView()
      }
      .tabItem {
        Label("Interactions", systemImage: "bubble.left.and.bubble.right.fill")
      }
      .accessibilityLabel("Interactions")

      NavigationStack {
        OffersListView()
      }
      .tabItem {
        Label("Offers", systemImage: "gift.fill")
      }
      .accessibilityLabel("Offers")

      NavigationStack {
        TasksListView()
      }
      .tabItem {
        Label("Tasks", systemImage: "checklist")
      }
      .accessibilityLabel("Tasks")

      NavigationStack {
        PerformanceDashboardView()
      }
      .tabItem {
        Label("Performance", systemImage: "chart.xyaxis.line")
      }
      .accessibilityLabel("Performance")

      NavigationStack {
        AnalyticsDashboardView()
      }
      .tabItem {
        Label("Analytics", systemImage: "chart.pie.fill")
      }
      .accessibilityLabel("Analytics")

      NavigationStack {
        ActivityFeedView()
          .activityNavigation()
      }
      .tabItem {
        Label("Activity", systemImage: "clock.fill")
      }
      .accessibilityLabel("Activity History")

      NavigationStack {
        NotificationsListView(viewModel: notificationsViewModel)
      }
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

      NavigationStack {
        SettingsView()
      }
      .tabItem {
        Label("Settings", systemImage: "gearshape.fill")
      }
      .accessibilityLabel("Settings")
    }
  }
}

#Preview {
  MainTabView()
    .environment(AuthManager.shared)
    .environment(FamilyManager.shared)
}
