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

      // Dashboard Widgets Section — reorderable live widgets (drag to arrange, toggle to show/hide)
      Section {
        ForEach(viewModel.visibility.widgetOrder) { id in
          HStack(spacing: 12) {
            Image(systemName: id.icon)
              .frame(width: 24)
              .foregroundStyle(.secondary)
              .accessibilityHidden(true)
            Text(id.label)
            Spacer()
            Toggle("", isOn: viewModel.binding(for: id))
              .labelsHidden()
              .accessibilityLabel(id.label)
          }
        }
        .onMove(perform: viewModel.moveWidget)
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
        Text("Tap Edit to drag widgets into your preferred order. Toggle to show or hide each on your dashboard.")
          .font(.caption)
      }

      // Coming Soon — widgets not yet available
      Section {
        LazyVGrid(columns: columns, spacing: 12) {
          ToggleCard(icon: "bell.badge.fill", label: String(localized: "Notifications"),
                     isOn: .constant(false), onChange: {}, isComingSoon: true)
          ToggleCard(icon: "link", label: String(localized: "Linked Accounts"),
                     isOn: .constant(false), onChange: {}, isComingSoon: true)
          ToggleCard(icon: "doc.badge.ellipsis", label: String(localized: "Offer Status"),
                     isOn: .constant(false), onChange: {}, isComingSoon: true)
          ToggleCard(icon: "chart.pie.fill", label: String(localized: "School Interest"),
                     isOn: .constant(false), onChange: {}, isComingSoon: true)
          ToggleCard(icon: "map.fill", label: String(localized: "School Map"),
                     isOn: .constant(false), onChange: {}, isComingSoon: true)
          ToggleCard(icon: "doc.richtext", label: String(localized: "Recent Docs"),
                     isOn: .constant(false), onChange: {}, isComingSoon: true)
          ToggleCard(icon: "chart.bar.xaxis", label: String(localized: "Interaction Stats"),
                     isOn: .constant(false), onChange: {}, isComingSoon: true)
          ToggleCard(icon: "building.columns.fill", label: String(localized: "School Status"),
                     isOn: .constant(false), onChange: {}, isComingSoon: true)
          ToggleCard(icon: "clock.badge.checkmark", label: String(localized: "Coach Response"),
                     isOn: .constant(false), onChange: {}, isComingSoon: true)
          ToggleCard(icon: "exclamationmark.triangle.fill", label: String(localized: "Deadlines"),
                     isOn: .constant(false), onChange: {}, isComingSoon: true)
        }
      } header: {
        Text("Coming Soon")
      } footer: {
        Text("These widgets aren't available yet.")
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
      ToolbarItem(placement: .topBarTrailing) {
        EditButton()
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
