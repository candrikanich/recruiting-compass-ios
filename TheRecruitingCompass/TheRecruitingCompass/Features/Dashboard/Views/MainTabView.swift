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

      NavigationStack {
        RecruitingTimelineView()
      }
      .tabItem {
        Label {
          Text("Timeline")
        } icon: {
          Image(systemName: "clock")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .accessibilityLabel("Recruiting Timeline")

      NavigationStack {
        EventsListView()
      }
      .tabItem {
        Label {
          Text("Events")
        } icon: {
          Image(systemName: "calendar")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .accessibilityLabel("Events")

      NavigationStack {
        DocumentsListView()
      }
      .tabItem {
        Label {
          Text("Documents")
        } icon: {
          Image(systemName: "doc")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .accessibilityLabel("Documents")

      NavigationStack {
        OffersListView()
      }
      .tabItem {
        Label {
          Text("Offers")
        } icon: {
          Image(systemName: "gift")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .accessibilityLabel("Offers")

      NavigationStack {
        PerformanceDashboardView()
      }
      .tabItem {
        Label {
          Text("Performance")
        } icon: {
          Image(systemName: "chart.xyaxis.line")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .accessibilityLabel("Performance")

      NavigationStack {
        AnalyticsDashboardView()
      }
      .tabItem {
        Label {
          Text("Analytics")
        } icon: {
          Image(systemName: "chart.pie")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .accessibilityLabel("Analytics")

      NavigationStack {
        ActivityFeedView()
          .activityNavigation()
      }
      .tabItem {
        Label {
          Text("Activity")
        } icon: {
          Image(systemName: "list.bullet.rectangle")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .accessibilityLabel("Activity History")

      NavigationStack {
        NotificationsListView(viewModel: notificationsViewModel)
      }
      .tabItem {
        Label {
          Text("Notifications")
        } icon: {
          Image(systemName: "bell")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .badge(notificationsViewModel.unreadCount > 0 ? notificationsViewModel.unreadCount : 0)
      .accessibilityLabel("Notifications")

      NavigationStack {
        FamilyManagementView()
      }
      .tabItem {
        Label {
          Text("Family")
        } icon: {
          Image(systemName: "person.3")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
      }
      .accessibilityLabel("Family")

      NavigationStack {
        SettingsView()
      }
      .tabItem {
        Label {
          Text("Settings")
        } icon: {
          Image(systemName: "gearshape")
            .fontWeight(.thin)
        }
        .environment(\.symbolVariants, .none)
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
