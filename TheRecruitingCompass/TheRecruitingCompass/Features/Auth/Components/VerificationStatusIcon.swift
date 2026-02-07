import SwiftUI

struct VerificationStatusIcon: View {
  let state: VerificationState
  @State private var isAnimating = false
  @Environment(\.sizeCategory) var sizeCategory

  private var backgroundSize: CGFloat {
    sizeCategory >= .extraLarge ? 88 : 80
  }

  private var iconSize: CGFloat {
    sizeCategory >= .extraLarge ? 44 : 40
  }

  private var accessibilityLabelForState: String {
    switch state {
    case .pending:
      return "Email verification pending"
    case .checking:
      return "Checking email verification status"
    case .verified:
      return "Email verified successfully"
    case .error(let message):
      return "Verification error: \(message)"
    }
  }

  var body: some View {
    ZStack {
      // Background circle
      Circle()
        .fill(backgroundColor)
        .frame(width: backgroundSize, height: backgroundSize)
        .accessibilityHidden(true)

      // Icon content
      Group {
        switch state {
        case .pending:
          Image(systemName: "envelope.fill")
            .font(.system(size: iconSize))
            .foregroundColor(Color.amberGold)
            .accessibilityHidden(true)

        case .checking:
          ProgressView()
            .tint(Color.accentBlue)
            .scaleEffect(1.5)
            .accessibilityLabel("Checking verification status")

        case .verified:
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: iconSize))
            .foregroundColor(Color.successGreen)
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isAnimating)
            .accessibilityHidden(true)

        case .error:
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: iconSize))
            .foregroundColor(Color.red)
            .accessibilityHidden(true)
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabelForState)
    .onAppear {
      if case .verified = state {
        isAnimating = true
      }
    }
  }

  private var backgroundColor: Color {
    switch state {
    case .pending:
      return Color.amberGold.opacity(0.15)
    case .checking:
      return Color.accentBlue.opacity(0.15)
    case .verified:
      return Color.successGreen.opacity(0.15)
    case .error:
      return Color.red.opacity(0.15)
    }
  }
}

#Preview {
  VStack(spacing: 32) {
    VerificationStatusIcon(state: .pending)
    VerificationStatusIcon(state: .checking)
    VerificationStatusIcon(state: .verified)
    VerificationStatusIcon(state: .error(message: "Failed"))
  }
  .padding()
}
