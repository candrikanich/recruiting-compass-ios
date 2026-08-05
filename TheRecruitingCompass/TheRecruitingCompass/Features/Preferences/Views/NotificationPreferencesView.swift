import SwiftUI
import UserNotifications

struct NotificationPreferencesView: View {
  @State private var viewModel: NotificationPreferencesViewModel
  @Environment(\.openURL) private var openURL
  @Environment(AuthManager.self) private var authManager
  @State private var pushAuthStatus: UNAuthorizationStatus = .notDetermined

  init(preferenceService: any PreferenceManaging, pushPreferencesService: (any PushPreferencesManaging)? = nil) {
    _viewModel = State(initialValue: NotificationPreferencesViewModel(
      preferenceService: preferenceService,
      pushPreferencesService: pushPreferencesService
    ))
  }

  var body: some View {
    Form {
      // In-App Notifications Section
      Section {
        Toggle("Coach Follow-Up Reminders", isOn: $viewModel.settings.enableFollowUpReminders)
          .onChange(of: viewModel.settings.enableFollowUpReminders) { _, _ in
            viewModel.markAsChanged()
          }
          .accessibilityLabel(String(localized: "Enable coach follow-up reminders"))

        if viewModel.settings.enableFollowUpReminders {
          Stepper(
            "Days between reminders: \(viewModel.settings.followUpReminderDays)",
            value: $viewModel.settings.followUpReminderDays,
            in: 1...90
          )
          .onChange(of: viewModel.settings.followUpReminderDays) { _, _ in
            viewModel.markAsChanged()
          }
          .accessibilityLabel(String(localized: "Days between follow-up reminders"))
          .accessibilityValue("\(viewModel.settings.followUpReminderDays) days")
        }

        Toggle("Deadline Alerts", isOn: $viewModel.settings.enableDeadlineAlerts)
          .onChange(of: viewModel.settings.enableDeadlineAlerts) { _, _ in
            viewModel.markAsChanged()
          }
          .accessibilityLabel(String(localized: "Enable deadline alerts"))

        Toggle("Daily Digest", isOn: $viewModel.settings.enableDailyDigest)
          .onChange(of: viewModel.settings.enableDailyDigest) { _, _ in
            viewModel.markAsChanged()
          }
          .accessibilityLabel(String(localized: "Enable daily digest"))

        Toggle("Inbound Contact Alerts", isOn: $viewModel.settings.enableInboundInteractionAlerts)
          .onChange(of: viewModel.settings.enableInboundInteractionAlerts) { _, _ in
            viewModel.markAsChanged()
          }
          .accessibilityLabel(String(localized: "Enable inbound contact alerts"))
      } header: {
        Text("In-App Notifications")
      }

      // Email Notifications Section
      Section {
        Toggle("Enable Email Notifications", isOn: $viewModel.settings.enableEmailNotifications)
          .onChange(of: viewModel.settings.enableEmailNotifications) { _, _ in
            viewModel.markAsChanged()
          }
          .accessibilityLabel(String(localized: "Enable email notifications"))

        if viewModel.settings.enableEmailNotifications {
          Toggle("High-Priority Only", isOn: $viewModel.settings.emailOnlyHighPriority)
            .onChange(of: viewModel.settings.emailOnlyHighPriority) { _, _ in
              viewModel.markAsChanged()
            }
            .accessibilityLabel(String(localized: "Email high-priority notifications only"))
            .padding(.leading, 16)
        }
      } header: {
        Text("Email Notifications")
      }

      // Push Notifications Section
      Section {
        if let pushSetupError = viewModel.pushSetupError {
          Label(pushSetupError, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(Color.errorRed)
        }
        if pushAuthStatus == .denied {
          HStack {
            Image(systemName: "bell.slash")
              .foregroundStyle(.secondary)
            Text("Push notifications are disabled in iOS Settings.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Open Settings") {
              if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
              }
            }
            .font(.subheadline)
          }
          .accessibilityElement(children: .contain)
        } else {
          ForEach(NotificationType.allCases.filter { $0 != .unknown }, id: \.self) { type in
            Toggle(type.label, isOn: Binding(
              get: { viewModel.pushPreferences[type] ?? true },
              set: { enabled in
                guard let userId = authManager.user?.id else { return }
                Task { await viewModel.updatePushPreference(userId: userId, type: type, enabled: enabled) }
              }
            ))
            .accessibilityLabel("Push notifications for \(type.label)")
          }
        }
      } header: {
        Text("Push Notifications")
      } footer: {
        if pushAuthStatus == .notDetermined {
          Text("Push notifications have not been enabled yet. You'll be prompted when you next use the app.")
            .font(.caption)
        } else if pushAuthStatus == .authorized || pushAuthStatus == .provisional {
          Text("Controls which notification types trigger a push alert on your device.")
            .font(.caption)
        }
      }

      // Actions Section
      Section {
        Button("Reset to Defaults") {
          Task {
            await viewModel.resetToDefaults()
          }
        }
        .foregroundStyle(.red)
        .accessibilityLabel(String(localized: "Reset notification preferences to defaults"))
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
    .sensoryFeedback(.success, trigger: viewModel.hapticSuccessTrigger)
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
      Task {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        pushAuthStatus = settings.authorizationStatus
      }
    }
    .task {
      let settings = await UNUserNotificationCenter.current().notificationSettings()
      pushAuthStatus = settings.authorizationStatus
      await viewModel.loadPreferences()
      if let userId = authManager.user?.id {
        await viewModel.loadPushPreferences(userId: userId)
      }
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
  .environment(AuthManager.shared)
}
