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
            label: String(localized: "Coaches"),
            isOn: $viewModel.visibility.statsCards.coaches,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "building.2.fill",
            label: String(localized: "Schools"),
            isOn: $viewModel.visibility.statsCards.schools,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "bubble.left.and.bubble.right.fill",
            label: String(localized: "Interactions"),
            isOn: $viewModel.visibility.statsCards.interactions,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "doc.text.fill",
            label: String(localized: "Offers"),
            isOn: $viewModel.visibility.statsCards.offers,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "calendar",
            label: String(localized: "Events"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
          )
          ToggleCard(
            icon: "chart.bar.fill",
            label: String(localized: "Performance"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
          )
          ToggleCard(
            icon: "bell.fill",
            label: String(localized: "Notifications"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
          )
          ToggleCard(
            icon: "at",
            label: String(localized: "Social Media"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
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
          .accessibilityLabel(viewModel.allStatsCardsEnabled ? String(localized: "Deselect all stats cards") : String(localized: "Select all stats cards"))
        }
      } footer: {
        Text("Choose which summary statistics appear on your dashboard.")
          .font(.caption)
      }

      // Dashboard Widgets Section
      Section {
        LazyVGrid(columns: columns, spacing: 12) {
          ToggleCard(
            icon: "sparkles",
            label: String(localized: "Action Items"),
            isOn: $viewModel.visibility.widgets.actionItems,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "checkmark.circle.fill",
            label: String(localized: "Quick Tasks"),
            isOn: $viewModel.visibility.widgets.quickTasks,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "eye.fill",
            label: String(localized: "At A Glance"),
            isOn: $viewModel.visibility.widgets.atAGlanceSummary,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "chart.line.uptrend.xyaxis",
            label: String(localized: "Interaction Trend"),
            isOn: $viewModel.visibility.widgets.interactionTrendChart,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "calendar.badge.clock",
            label: String(localized: "Events Summary"),
            isOn: $viewModel.visibility.widgets.eventsSummary,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "person.wave.2.fill",
            label: String(localized: "Coaches Follow-up"),
            isOn: $viewModel.visibility.widgets.coachFollowupWidget,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "chart.bar.doc.horizontal",
            label: String(localized: "Performance"),
            isOn: $viewModel.visibility.widgets.performanceSummary,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "clock.arrow.circlepath",
            label: String(localized: "Recent Activity"),
            isOn: $viewModel.visibility.widgets.recentActivity,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "doc.text.fill",
            label: String(localized: "Recruiting Packet"),
            isOn: $viewModel.visibility.widgets.recruitingPacket,
            onChange: { viewModel.markChanged() }
          )

          ToggleCard(
            icon: "bell.badge.fill",
            label: String(localized: "Notifications"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
          )
          ToggleCard(
            icon: "link",
            label: String(localized: "Linked Accounts"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
          )
          ToggleCard(
            icon: "calendar",
            label: String(localized: "Recruiting Calendar"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
          )
          ToggleCard(
            icon: "doc.badge.ellipsis",
            label: String(localized: "Offer Status"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
          )
          ToggleCard(
            icon: "chart.pie.fill",
            label: String(localized: "School Interest"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
          )
          ToggleCard(
            icon: "map.fill",
            label: String(localized: "School Map"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
          )
          ToggleCard(
            icon: "doc.richtext",
            label: String(localized: "Recent Docs"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
          )
          ToggleCard(
            icon: "chart.bar.xaxis",
            label: String(localized: "Interaction Stats"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
          )
          ToggleCard(
            icon: "building.columns.fill",
            label: String(localized: "School Status"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
          )
          ToggleCard(
            icon: "clock.badge.checkmark",
            label: String(localized: "Coach Response"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
          )
          ToggleCard(
            icon: "exclamationmark.triangle.fill",
            label: String(localized: "Deadlines"),
            isOn: .constant(false),
            onChange: {},
            isComingSoon: true
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
          .accessibilityLabel(viewModel.allWidgetsEnabled ? String(localized: "Deselect all widgets") : String(localized: "Select all widgets"))
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
        .foregroundStyle(.red)
        .accessibilityLabel(String(localized: "Reset dashboard settings to defaults"))
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
        message: String(localized: "Loading settings...")
      )
    }
    .preferenceErrorAlert(errorMessage: $viewModel.errorMessage)
    .sensoryFeedback(.success, trigger: viewModel.hapticSuccessTrigger)
    .task {
      await viewModel.loadVisibility()
    }
  }
}

#Preview {
  NavigationStack {
    DashboardCustomizationView(
      preferenceService: PreferencePreviewMock(defaultValue: DashboardWidgetVisibility.default)
    )
  }
}
