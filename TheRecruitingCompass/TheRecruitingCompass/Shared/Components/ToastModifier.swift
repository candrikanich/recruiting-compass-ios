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
        .onAppear {
          Task {
            try? await Task.sleep(for: .seconds(duration))
            dismiss()
          }
        }
      }
    }
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
