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
        Label("Dashboard", systemImage: "house")
      }
      .accessibilityLabel("Dashboard")

      NavigationStack {
        CoachesListView()
      }
      .tabItem {
        Label("Coaches", systemImage: "person.2")
      }
      .accessibilityLabel("Coaches")

      NavigationStack {
        SchoolsListView()
      }
      .tabItem {
        Label("Schools", systemImage: "building.2")
      }
      .accessibilityLabel("Schools")

      NavigationStack {
        InteractionsListView()
      }
      .tabItem {
        Label("Interactions", systemImage: "bubble.left.and.bubble.right")
      }
      .accessibilityLabel("Interactions")

      NavigationStack {
        RecruitingTimelineView()
      }
      .tabItem {
        Label("Timeline", systemImage: "clock")
      }
      .accessibilityLabel("Recruiting Timeline")

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
        Label("Documents", systemImage: "doc")
      }
      .accessibilityLabel("Documents")

      NavigationStack {
        OffersListView()
      }
      .tabItem {
        Label("Offers", systemImage: "gift")
      }
      .accessibilityLabel("Offers")

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
        Label("Analytics", systemImage: "chart.pie")
      }
      .accessibilityLabel("Analytics")

      NavigationStack {
        ActivityFeedView()
          .activityNavigation()
      }
      .tabItem {
        Label("Activity", systemImage: "list.bullet.rectangle")
      }
      .accessibilityLabel("Activity History")

      NavigationStack {
        NotificationsListView(viewModel: notificationsViewModel)
      }
      .tabItem {
        Label("Notifications", systemImage: "bell")
      }
      .badge(notificationsViewModel.unreadCount > 0 ? notificationsViewModel.unreadCount : 0)
      .accessibilityLabel("Notifications")

      NavigationStack {
        FamilyManagementView()
      }
      .tabItem {
        Label("Family", systemImage: "person.3")
      }
      .accessibilityLabel("Family")

      NavigationStack {
        SettingsView()
      }
      .tabItem {
        Label("Settings", systemImage: "gearshape")
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
