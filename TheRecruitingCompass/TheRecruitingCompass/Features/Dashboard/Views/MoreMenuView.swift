//
//  MoreMenuView.swift
//  TheRecruitingCompass
//
//  Custom "More" menu to avoid iOS TabView overflow double nav bar.
//  Path-based NavigationStack to avoid nested stack issues with Events.
//  Styled like Settings with section headers and icon rows.
//

import SwiftUI

struct MoreMenuView: View {
  @State private var path = NavigationPath()
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
      path = NavigationPath()
      newPath.forEach { path.append($0) }
      externalPath = []
    }
  }

  @ViewBuilder
  private var moreMenuList: some View {
    List {
      menuSectionView("Recruiting", items: [.timeline, .events, .documents, .offers, .performance, .analytics, .activity])
      menuSectionView("Account", items: [.notifications, .settings])
      menuSectionView("Support", items: [.helpCenter])
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
      EventsListView()
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
    .accessibilityLabel(String(localized: "\(section.title)"))
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
    .accessibilityLabel(badgeCount.map { String(localized: "\(title), \($0) unread") } ?? String(localized: "\(title): \(description)"))
  }
}

#Preview {
  MoreMenuView(notificationsViewModel: NotificationsListViewModel())
    .environment(AuthManager.shared)
    .environment(FamilyManager.shared)
}
