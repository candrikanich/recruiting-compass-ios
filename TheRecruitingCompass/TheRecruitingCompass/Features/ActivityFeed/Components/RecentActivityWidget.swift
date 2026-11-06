import SwiftUI

struct RecentActivityWidget: View {
  @State private var viewModel = ActivityFeedViewModel()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(FamilyManager.self) private var familyManager

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      HStack {
        Text("Recent Activity")
          .font(.brand(.headline))
          .accessibilityAddTraits(.isHeader)

        Spacer()

        Button {
          Task { await viewModel.refresh() }
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.brand(.subheadline))
            .foregroundStyle(Color.accentPrimary)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(refreshAccessibilityLabel)
        .accessibilityIdentifier("recent-activity-refresh")
      }

      Divider()

      switch viewModel.presentation {
      case .loading:
        ProgressView()
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 16)
      case .failed(let message):
        VStack(spacing: 8) {
          Text(message)
            .font(.brand(.caption))
            .foregroundStyle(Color.secondaryText)
            .multilineTextAlignment(.center)
          Button("Try Again") {
            Task { await viewModel.refresh() }
          }
          .font(.brand(.caption))
          .frame(minWidth: 44, minHeight: 44)
          .accessibilityIdentifier("recent-activity-retry")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recent-activity-error-state")
      case .empty:
        Text("No recent activity")
          .font(.brand(.caption))
          .foregroundStyle(Color.secondaryText)
          .padding(.vertical, 16)
      case .content:
        VStack(spacing: 8) {
          ForEach(viewModel.recentActivities) { event in
            if event.isClickable {
              NavigationLink(value: ActivityDestination(event: event)) {
                ActivityEventItem(
                  event: event, compact: true, actorLabel: viewModel.actorLabel(for: event))
              }
              .buttonStyle(.plain)
            } else {
              ActivityEventItem(
                  event: event, compact: true, actorLabel: viewModel.actorLabel(for: event))
            }
          }
        }

        // "View All" link
        NavigationLink(value: ActivityFeedDestination.fullPage) {
          HStack(spacing: 4) {
            Text("View All Activity")
              .font(.brand(.caption))
            Image(systemName: "chevron.right")
              .font(.brand(.caption))
              .accessibilityHidden(true)
          }
          .foregroundStyle(Color.accentPrimary)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(viewAllAccessibilityLabel)
        .accessibilityHint(viewAllAccessibilityHint)
        .accessibilityIdentifier("recent-activity-view-all")
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
    .accessibilityIdentifier("recent-activity-widget")
    .task {
      await viewModel.loadAndSubscribe()
    }
    .onChange(of: familyManager.familyUnitId) { _, _ in
      Task { await viewModel.familyDidChange() }
    }
    .onDisappear {
      Task { await viewModel.tearDownRealtime() }
    }
    .onChange(of: scenePhase) { _, newValue in
      if newValue == .active {
        Task { await viewModel.loadAndSubscribe() }
      } else if newValue == .background {
        Task { await viewModel.tearDownRealtime() }
      }
    }
  }

  // MARK: - Accessibility

  var refreshAccessibilityLabel: String { String(localized: "Refresh activities") }
  var viewAllAccessibilityLabel: String { String(localized: "View all activity") }
  var viewAllAccessibilityHint: String { "Opens the full activity history page" }
}

#Preview {
  NavigationStack {
    RecentActivityWidget()
      .padding()
  }
}
