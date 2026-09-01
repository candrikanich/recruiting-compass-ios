import SwiftUI
import UserNotifications

/// Pre-permission priming screen shown after the user adds their first school
/// during onboarding Step 2. Explains the value of push notifications before
/// requesting system permission. Replaces the auto-request in TheRecruitingCompassApp.
struct PushNotificationPrimingView: View {
  var onDismiss: () -> Void

  @Environment(NuxProgressManager.self) private var nuxProgressManager

  var body: some View {
    VStack(spacing: 32) {
      Spacer()

      Image(systemName: "bell.badge.fill")
        .font(.system(size: 56))
        .foregroundStyle(Color.accentColor)
        .symbolRenderingMode(.hierarchical)

      VStack(spacing: 12) {
        Text("Stay on top of recruiting")
          .font(.title2.weight(.bold))
          .multilineTextAlignment(.center)

        Text("Get notified about recruiting deadlines, coach activity, and task reminders.")
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      Spacer()

      VStack(spacing: 12) {
        Button {
          Task {
            await requestPushPermission()
            onDismiss()
          }
        } label: {
          Text("Turn on notifications")
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("enablePushNotificationsButton")

        Button {
          nuxProgressManager.dismissPrompt("push_priming")
          onDismiss()
        } label: {
          Text("Not now")
            .font(.body)
            .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("skipPushNotificationsButton")
      }
    }
    .padding(32)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("pushNotificationPrimingView")
  }

  private func requestPushPermission() async {
    let center = UNUserNotificationCenter.current()
    do {
      let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
      if granted {
        await MainActor.run {
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
    } catch {
      // Permission request failed; user can enable later from device Settings
    }
  }
}
