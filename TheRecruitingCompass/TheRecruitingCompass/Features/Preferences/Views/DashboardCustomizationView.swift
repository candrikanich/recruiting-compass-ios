import SwiftUI

struct DashboardCustomizationView: View {
  @State private var viewModel: DashboardCustomizationViewModel

  private let columns = [
    GridItem(.flexible()),
    GridItem(.flexible())
  ]

  init(preferenceService: PreferenceManaging) {
    _viewModel = State(initialValue: DashboardCustomizationViewModel(preferenceService: preferenceService))
  }

  var body: some View {
    Form {
      // Stats Cards Section
      Section {
        LazyVGrid(columns: columns, spacing: 12) {
          ToggleCard(
            icon: "person.3.fill",
            label: "Coaches",
            isOn: $viewModel.visibility.statsCards.coaches,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "building.2.fill",
            label: "Schools",
            isOn: $viewModel.visibility.statsCards.schools,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "bubble.left.and.bubble.right.fill",
            label: "Interactions",
            isOn: $viewModel.visibility.statsCards.interactions,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "doc.text.fill",
            label: "Offers",
            isOn: $viewModel.visibility.statsCards.offers,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "calendar",
            label: "Events",
            isOn: $viewModel.visibility.statsCards.events,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "chart.bar.fill",
            label: "Performance",
            isOn: $viewModel.visibility.statsCards.performance,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "bell.fill",
            label: "Notifications",
            isOn: $viewModel.visibility.statsCards.notifications,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "at",
            label: "Social Media",
            isOn: $viewModel.visibility.statsCards.socialMedia,
            onChange: { viewModel.markChanged() }
          )
        }
      } header: {
        HStack {
          Text("Summary Statistics")
          Spacer()
          Button(viewModel.allStatsCardsEnabled ? "Deselect All" : "Select All") {
            viewModel.toggleAllStatsCards(!viewModel.allStatsCardsEnabled)
          }
          .font(.caption)
          .accessibilityLabel(viewModel.allStatsCardsEnabled ? "Deselect all stats cards" : "Select all stats cards")
        }
      } footer: {
        Text("Choose which summary statistics appear on your dashboard.")
          .font(.caption)
      }

      // Dashboard Widgets Section
      Section {
        LazyVGrid(columns: columns, spacing: 12) {
          ToggleCard(
            icon: "bell.badge.fill",
            label: "Recent Notifications",
            isOn: $viewModel.visibility.widgets.recentNotifications,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "link",
            label: "Linked Accounts",
            isOn: $viewModel.visibility.widgets.linkedAccounts,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "calendar",
            label: "Recruiting Calendar",
            isOn: $viewModel.visibility.widgets.recruitingCalendar,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "checkmark.circle.fill",
            label: "Quick Tasks",
            isOn: $viewModel.visibility.widgets.quickTasks,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "eye.fill",
            label: "At A Glance",
            isOn: $viewModel.visibility.widgets.atAGlanceSummary,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "doc.badge.ellipsis",
            label: "Offer Status",
            isOn: $viewModel.visibility.widgets.offerStatusOverview,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "chart.line.uptrend.xyaxis",
            label: "Interaction Trend",
            isOn: $viewModel.visibility.widgets.interactionTrendChart,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "chart.pie.fill",
            label: "School Interest",
            isOn: $viewModel.visibility.widgets.schoolInterestChart,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "map.fill",
            label: "School Map",
            isOn: $viewModel.visibility.widgets.schoolMapWidget,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "person.wave.2.fill",
            label: "Coach Follow-up",
            isOn: $viewModel.visibility.widgets.coachFollowupWidget,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "calendar.badge.clock",
            label: "Events Summary",
            isOn: $viewModel.visibility.widgets.eventsSummary,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "chart.bar.doc.horizontal",
            label: "Performance",
            isOn: $viewModel.visibility.widgets.performanceSummary,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "doc.richtext",
            label: "Recent Docs",
            isOn: $viewModel.visibility.widgets.recentDocuments,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "chart.bar.xaxis",
            label: "Interaction Stats",
            isOn: $viewModel.visibility.widgets.interactionStats,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "building.columns.fill",
            label: "School Status",
            isOn: $viewModel.visibility.widgets.schoolStatusOverview,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "clock.badge.checkmark",
            label: "Coach Response",
            isOn: $viewModel.visibility.widgets.coachResponsiveness,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "exclamationmark.triangle.fill",
            label: "Deadlines",
            isOn: $viewModel.visibility.widgets.upcomingDeadlines,
            onChange: { viewModel.markChanged() }
          )
        }
      } header: {
        HStack {
          Text("Dashboard Widgets")
          Spacer()
          Button(viewModel.allWidgetsEnabled ? "Deselect All" : "Select All") {
            viewModel.toggleAllWidgets(!viewModel.allWidgetsEnabled)
          }
          .font(.caption)
          .accessibilityLabel(viewModel.allWidgetsEnabled ? "Deselect all widgets" : "Select all widgets")
        }
      } footer: {
        Text("Choose which widgets appear on your dashboard.")
          .font(.caption)
      }

      // Reset Section
      Section {
        Button("Reset to Defaults") {
          Task {
            await viewModel.resetToDefaults()
          }
        }
        .foregroundColor(.red)
        .accessibilityLabel("Reset dashboard settings to defaults")
        .disabled(viewModel.saveStatus == .saving)
      }
    }
    .navigationTitle("Dashboard")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        SaveStatusView(status: viewModel.saveStatus)
      }
    }
    .overlay {
      PreferenceLoadingOverlay(
        isLoading: viewModel.isLoading,
        message: "Loading settings..."
      )
    }
    .preferenceErrorAlert(errorMessage: $viewModel.errorMessage)
    .task {
      await viewModel.loadVisibility()
    }
  }
}

// MARK: - Toggle Card Component

struct ToggleCard: View {
  let icon: String
  let label: String
  @Binding var isOn: Bool
  let onChange: () -> Void

  var body: some View {
    Button {
      isOn.toggle()
      onChange()
    } label: {
      VStack(spacing: 8) {
        Image(systemName: icon)
          .font(.title2)
          .foregroundColor(isOn ? .blue : .gray)

        Text(label)
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(.primary)
          .multilineTextAlignment(.center)
          .lineLimit(2)

        if isOn {
          Image(systemName: "checkmark.circle.fill")
            .font(.caption)
            .foregroundColor(.green)
        } else {
          Image(systemName: "circle")
            .font(.caption)
            .foregroundColor(.gray)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isOn ? Color.blue.opacity(0.1) : Color(.systemGray6))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(isOn ? Color.blue : Color.clear, lineWidth: 3)
      )
      .scaleEffect(isOn ? 1.0 : 0.98)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(label) \(isOn ? "enabled" : "disabled")")
    .accessibilityHint("Tap to toggle")
    .accessibilityAddTraits(isOn ? .isSelected : [])
  }
}

struct DashboardCustomizationView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      DashboardCustomizationView(
        preferenceService: PreferencePreviewMock(defaultValue: DashboardWidgetVisibility.default)
      )
    }
  }
}
