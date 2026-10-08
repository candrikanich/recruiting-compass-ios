import SwiftUI

struct ToastModifier: ViewModifier {
  @Binding var isShowing: Bool
  @Binding var message: String?
  let type: ToastType
  let duration: TimeInterval

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content.overlay(alignment: .top) {
      if isShowing, let message {
        Toast(message: message, type: type) {
          dismiss()
        }
        .padding(.top, 8)
        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        .task(id: message) {
          AccessibilityNotification.Announcement(type.announcement(for: message)).post()
          let assistiveTechnologyRunning = UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
          guard let delay = Self.autoDismissDelay(
            duration: duration,
            assistiveTechnologyRunning: assistiveTechnologyRunning
          ) else { return }
          // A cancelled sleep means this toast was already dismissed or replaced.
          guard (try? await Task.sleep(for: .seconds(delay))) != nil else { return }
          dismiss()
        }
      }
    }
  }

  /// A toast that vanishes on a timer cannot be reached with VoiceOver or Switch Control, so with either
  /// running it stays until the user dismisses it.
  static func autoDismissDelay(duration: TimeInterval, assistiveTechnologyRunning: Bool) -> TimeInterval? {
    assistiveTechnologyRunning ? nil : duration
  }

  /// Fades rather than slides under Reduce Motion; the transition above drops the move.
  private func dismiss() {
    withAnimation {
      isShowing = false
      message = nil
    }
  }
}

extension View {
  func toast(
    isShowing: Binding<Bool>,
    message: Binding<String?>,
    type: ToastType = .success,
    duration: TimeInterval = 3.0
  ) -> some View {
    modifier(ToastModifier(
      isShowing: isShowing,
      message: message,
      type: type,
      duration: duration
    ))
  }
}
