import SwiftUI

// MARK: - Toast View

struct Toast: View {
  let message: String
  let type: ToastType
  let onDismiss: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: type.iconName)
        .font(.body)
        .foregroundStyle(type.iconColor)
        .accessibilityHidden(true)

      Text(message)
        .font(.subheadline)
        .foregroundStyle(.primary)
        .multilineTextAlignment(.leading)

      Spacer()

      Button {
        onDismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("Dismiss notification")
    }
    .padding(16)
    .background(Color.Surface.card, in: RoundedRectangle(cornerRadius: 12))
    .brandShadowMd()
    .padding(.horizontal, 16)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(message)
    .accessibilityAddTraits(.updatesFrequently)
  }
}

enum ToastType {
  case success
  case error
  case info
  case warning

  var iconName: String {
    switch self {
    case .success: return "checkmark.circle.fill"
    case .error: return "exclamationmark.circle.fill"
    case .info: return "info.circle.fill"
    case .warning: return "exclamationmark.triangle.fill"
    }
  }

  var iconColor: Color {
    switch self {
    case .success: return .successGreen
    case .error: return .errorRed
    case .info: return .accentBlue
    case .warning: return Color(hex: "F59E0B") // Amber
    }
  }
}

// MARK: - Toast Modifier

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

// MARK: - Previews

#Preview {
  VStack(spacing: 16) {
    Toast(message: "Coach deleted successfully", type: .success) {}
    Toast(message: "Coach and 3 interactions deleted", type: .success) {}
    Toast(message: "Failed to delete coach", type: .error) {}
    Toast(message: "New coach added", type: .info) {}
  }
}
