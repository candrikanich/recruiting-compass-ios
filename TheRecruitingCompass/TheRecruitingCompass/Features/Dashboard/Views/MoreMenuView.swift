//
//  MoreMenuView.swift
//  TheRecruitingCompass
//
//  Custom "More" menu to avoid iOS TabView overflow double nav bar.
//  Path-based NavigationStack to avoid nested stack issues with Events.
//  Styled like Settings with section headers and icon rows.
//

import SwiftUI

enum MoreMenuSection: String, CaseIterable, Identifiable {
  case timeline
  case events
  case documents
  case offers
  case performance
  case analytics
  case activity
  case helpCenter
  case notifications
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
    case .helpCenter: return "Help Center"
    case .notifications: return "Notifications"
    case .settings: return "Settings"
    }
  }

  var description: String {
    switch self {
    case .timeline: return "Phases, milestones, and recruiting roadmap"
    case .events: return "Camps, visits, and key dates"
    case .documents: return "Transcripts, videos, and files"
    case .offers: return "Scholarship and offer tracking"
    case .performance: return "Stats, metrics, and progress"
    case .analytics: return "Charts and recruiting insights"
    case .activity: return "History of your recruiting activity"
    case .helpCenter: return "Guides and FAQs for using the app"
    case .notifications: return "Alerts and follow-up reminders"
    case .settings: return "Preferences and account settings"
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
    case .helpCenter: return "questionmark.circle"
    case .notifications: return "bell"
    case .settings: return "gearshape"
    }
  }

  var color: Color {
    switch self {
    case .timeline: return .blue
    case .events: return .purple
    case .documents: return .blue
    case .offers: return .green
    case .performance: return .orange
    case .analytics: return .purple
    case .activity: return .accentBlue
    case .helpCenter: return .accentBlue
    case .notifications: return .orange
    case .settings: return Color.iconGray
    }
  }

  /// Sections grouped for list display (header title → items).
  static var recruitingSections: [(header: String, items: [MoreMenuSection])] {
    [
      ("Recruiting", [.timeline, .events, .documents, .offers, .performance, .analytics, .activity]),
      ("Support", [.helpCenter]),
      ("Account", [.notifications, .settings])
    ]
  }
}

enum MorePath: Hashable {
  case section(MoreMenuSection)
  case eventDetail(eventId: String)
  case offerDetail(offerId: String)
  case helpSection(slug: String)
}

struct MoreMenuView: View {
  @State private var path: [MorePath] = []
  @Binding var externalPath: [MorePath]
  var notificationsViewModel: NotificationsListViewModel

  init(notificationsViewModel: NotificationsListViewModel, path: Binding<[MorePath]>? = nil) {
    self.notificationsViewModel = notificationsViewModel
    self._externalPath = path ?? .constant([])
  }

  var body: some View {
    NavigationStack(path: $path) {
      moreMenuList
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: MorePath.self) { morePath in
          destinationView(for: morePath)
        }
    }
    .onChange(of: externalPath) { _, newPath in
      guard !newPath.isEmpty else { return }
      path = newPath
      externalPath = []
    }
  }

  @ViewBuilder
  private var moreMenuList: some View {
    List {
      menuSectionView("Recruiting", items: [.timeline, .events, .documents, .offers, .performance, .analytics, .activity])
      menuSectionView("Support", items: [.helpCenter])
      menuSectionView("Account", items: [.notifications, .settings])
    }
  }

  @ViewBuilder
  private func menuSectionView(_ header: String, items: [MoreMenuSection]) -> some View {
    Section(header) {
      ForEach(items) { (item: MoreMenuSection) in
        MoreMenuSectionRow(section: item, unreadCount: notificationsViewModel.unreadCount)
      }
    }
  }

  @ViewBuilder
  private func destinationView(for morePath: MorePath) -> some View {
    switch morePath {
    case .section(let menuSection):
      sectionDestination(menuSection)
    case .eventDetail(let eventId):
      EventDetailView(eventId: eventId)
    case .offerDetail(let offerId):
      OfferDetailView(offerId: offerId)
    case .helpSection(let slug):
      let helpSection = HelpSection(slug: slug) ?? .gettingStarted
      HelpSectionDetailView(section: helpSection)
    }
  }

  @ViewBuilder
  private func sectionDestination(_ section: MoreMenuSection) -> some View {
    switch section {
    case .timeline:
      RecruitingTimelineView()
    case .events:
      EventsListView(path: $path)
    case .documents:
      DocumentsListView()
    case .offers:
      OffersListView()
    case .performance:
      PerformanceDashboardView()
    case .analytics:
      AnalyticsDashboardView()
    case .activity:
      ActivityFeedView()
        .activityNavigation()
    case .helpCenter:
      HelpCenterView()
    case .notifications:
      NotificationsListView(viewModel: notificationsViewModel)
    case .settings:
      SettingsView()
    }
  }
}

// MARK: - More Menu Section Row (breaks up type-checker complexity)
private struct MoreMenuSectionRow: View {
  let section: MoreMenuSection
  let unreadCount: Int

  var body: some View {
    NavigationLink(value: MorePath.section(section)) {
      MoreMenuRow(
        icon: section.icon,
        title: section.title,
        description: section.description,
        color: section.color,
        badgeCount: section == .notifications && unreadCount > 0 ? unreadCount : nil
      )
    }
    .accessibilityLabel(section.title)
    .accessibilityHint("Opens \(section.title)")
  }
}

// MARK: - More Menu Row (matches Settings row style)
private struct MoreMenuRow: View {
  let icon: String
  let title: String
  let description: String
  let color: Color
  var badgeCount: Int?

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundStyle(.white)
        .frame(width: 36, height: 36)
        .background(color)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(title)
            .font(.body)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
          if let count = badgeCount {
            Text("\(count)")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(.white)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.red)
              .clipShape(Capsule())
          }
        }
        Text(description)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(badgeCount.map { "\(title), \($0) unread" } ?? "\(title): \(description)")
  }
}

#Preview {
  MoreMenuView(notificationsViewModel: NotificationsListViewModel())
    .environment(AuthManager.shared)
    .environment(FamilyManager.shared)
}
