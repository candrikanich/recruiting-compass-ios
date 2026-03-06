import SwiftUI

struct NotificationPreferencesView: View {
  @State private var viewModel: NotificationPreferencesViewModel

  init(preferenceService: PreferenceManaging) {
    _viewModel = State(initialValue: NotificationPreferencesViewModel(preferenceService: preferenceService))
  }

  var body: some View {
    Form {
      // In-App Notifications Section
      Section {
        Toggle("Coach Follow-Up Reminders", isOn: $viewModel.settings.enableFollowUpReminders)
          .onChange(of: viewModel.settings.enableFollowUpReminders) { _, _ in
            viewModel.markAsChanged()
          }
          .accessibilityLabel("Enable coach follow-up reminders")

        if viewModel.settings.enableFollowUpReminders {
          Stepper(
            "Days between reminders: \(viewModel.settings.followUpReminderDays)",
            value: $viewModel.settings.followUpReminderDays,
            in: 1...90
          )
          .onChange(of: viewModel.settings.followUpReminderDays) { _, _ in
            viewModel.markAsChanged()
          }
          .accessibilityLabel("Days between follow-up reminders")
          .accessibilityValue("\(viewModel.settings.followUpReminderDays) days")
        }

        Toggle("Deadline Alerts", isOn: $viewModel.settings.enableDeadlineAlerts)
          .onChange(of: viewModel.settings.enableDeadlineAlerts) { _, _ in
            viewModel.markAsChanged()
          }
          .accessibilityLabel("Enable deadline alerts")

        Toggle("Daily Digest", isOn: $viewModel.settings.enableDailyDigest)
          .onChange(of: viewModel.settings.enableDailyDigest) { _, _ in
            viewModel.markAsChanged()
          }
          .accessibilityLabel("Enable daily digest")

        Toggle("Inbound Contact Alerts", isOn: $viewModel.settings.enableInboundInteractionAlerts)
          .onChange(of: viewModel.settings.enableInboundInteractionAlerts) { _, _ in
            viewModel.markAsChanged()
          }
          .accessibilityLabel("Enable inbound contact alerts")
      } header: {
        Text("In-App Notifications")
      }

      // Email Notifications Section
      Section {
        Toggle("Enable Email Notifications", isOn: $viewModel.settings.enableEmailNotifications)
          .onChange(of: viewModel.settings.enableEmailNotifications) { _, _ in
            viewModel.markAsChanged()
          }
          .accessibilityLabel("Enable email notifications")

        if viewModel.settings.enableEmailNotifications {
          Toggle("High-Priority Only", isOn: $viewModel.settings.emailOnlyHighPriority)
            .onChange(of: viewModel.settings.emailOnlyHighPriority) { _, _ in
              viewModel.markAsChanged()
            }
            .accessibilityLabel("Email high-priority notifications only")
            .padding(.leading, 16)
        }
      } header: {
        Text("Email Notifications")
      }

      // Actions Section
      Section {
        Button("Reset to Defaults") {
          Task {
            await viewModel.resetToDefaults()
          }
        }
        .foregroundColor(.red)
        .accessibilityLabel("Reset notification preferences to defaults")
        .disabled(viewModel.saveStatus == .saving)
      }
    }
    .navigationTitle("Notifications")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        SaveStatusView(status: viewModel.saveStatus)
      }
    }
    .overlay {
      PreferenceLoadingOverlay(
        isLoading: viewModel.isLoading,
        message: "Loading preferences..."
      )
    }
    .preferenceErrorAlert(errorMessage: $viewModel.errorMessage)
    .task {
      await viewModel.loadPreferences()
    }
  }
}

#Preview {
  // Simple preview mock
  final class PreviewMock: PreferenceManaging {
    func fetchPreferences<T: Codable>(category: PreferenceCategory) async throws -> T? {
      return NotificationSettings.default as? T
    }
    func savePreferences<T: Codable>(category: PreferenceCategory, data: T) async throws -> T { data }
    func deletePreferences(category: PreferenceCategory) async throws {}
  }

  return NavigationStack {
    NotificationPreferencesView(preferenceService: PreviewMock())
  }
}
