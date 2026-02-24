//
//  MoreMenuView.swift
//  TheRecruitingCompass
//
//  Custom "More" menu to avoid iOS TabView overflow double nav bar.
//  Path-based NavigationStack to avoid nested stack issues with Events.
//

import SwiftUI

enum MorePath: Hashable {
  case section(MoreMenuView.Section)
  case eventDetail(eventId: String)
}

struct MoreMenuView: View {
  enum Section: String, CaseIterable, Identifiable {
    case timeline
    case events
    case documents
    case offers
    case performance
    case analytics
    case activity
    case notifications
    case family
    case settings

    var id: String { rawValue }

    var title: String {
      switch self {
      case .timeline: return "Recruiting Timeline"
      case .events: return "Events"
      case .documents: return "Documents"
      case .offers: return "Offers"
      case .performance: return "Performance"
      case .analytics: return "Analytics"
      case .activity: return "Activity History"
      case .notifications: return "Notifications"
      case .family: return "Family"
      case .settings: return "Settings"
      }
    }

    var icon: String {
      switch self {
      case .timeline: return "clock"
      case .events: return "calendar"
      case .documents: return "doc"
      case .offers: return "gift"
      case .performance: return "chart.xyaxis.line"
      case .analytics: return "chart.pie"
      case .activity: return "list.bullet.rectangle"
      case .notifications: return "bell"
      case .family: return "person.3"
      case .settings: return "gearshape"
      }
    }
  }

  @State private var path: [MorePath] = []
  var notificationsViewModel: NotificationsListViewModel

  var body: some View {
    NavigationStack(path: $path) {
      List {
        ForEach(Section.allCases) { section in
          NavigationLink(value: MorePath.section(section)) {
            Label {
            Text(section.title)
            if section == .notifications, notificationsViewModel.unreadCount > 0 {
              Spacer()
              Text("\(notificationsViewModel.unreadCount)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red)
                .clipShape(Capsule())
            }
            } icon: {
              Image(systemName: section.icon)
                .fontWeight(.thin)
            }
          }
          .accessibilityLabel(section.title)
          .accessibilityHint("Opens \(section.title)")
        }
      }
      .navigationTitle("More")
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(for: MorePath.self) { morePath in
        destinationView(for: morePath)
      }
    }
  }

  @ViewBuilder
  private func destinationView(for morePath: MorePath) -> some View {
    switch morePath {
    case .section(let section):
      sectionDestination(section)
    case .eventDetail(let eventId):
      EventDetailView(eventId: eventId)
    }
  }

  @ViewBuilder
  private func sectionDestination(_ section: Section) -> some View {
    switch section {
    case .timeline:
      RecruitingTimelineView()
    case .events:
      EventsListView(path: $path)
    case .documents:
      DocumentsListView(embedInNavigationStack: false)
    case .offers:
      OffersListView()
    case .performance:
      PerformanceDashboardView()
    case .analytics:
      AnalyticsDashboardView()
    case .activity:
      ActivityFeedView()
        .activityNavigation()
    case .notifications:
      NotificationsListView(viewModel: notificationsViewModel)
    case .family:
      FamilyManagementView()
    case .settings:
      SettingsView()
    }
  }
}

#Preview {
  MoreMenuView(notificationsViewModel: NotificationsListViewModel())
    .environment(AuthManager.shared)
    .environment(FamilyManager.shared)
}
