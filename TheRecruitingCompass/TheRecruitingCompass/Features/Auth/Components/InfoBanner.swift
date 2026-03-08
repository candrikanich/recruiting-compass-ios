import SwiftUI

struct InfoBanner: View {
  let state: VerificationState
  let email: String?
  @Environment(\.sizeCategory) var sizeCategory

  init(state: VerificationState, email: String? = nil) {
    self.state = state
    self.email = email
  }

  private var iconSize: CGFloat {
    sizeCategory >= .extraLarge ? 22 : 20
  }

  var body: some View {
    if !isErrorState {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 12) {
          icon
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 4) {
            Text(title)
              .font(.footnote.weight(.semibold))
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(Color.secondaryText)
          }
          Spacer()
        }
        .padding(12)
      }
      .background(backgroundColor)
      .clipShape(.rect(cornerRadius: 8))
      .transition(.opacity)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(title)
      .accessibilityValue(subtitle)
      .accessibilityAddTraits(.isHeader)
    }
  }

  // MARK: - Private Properties

  private var isErrorState: Bool {
    if case .error = state { return true }
    return false
  }

  private var icon: some View {
    Group {
      switch state {
      case .pending:
        Image(systemName: "envelope.fill")
          .font(.system(size: iconSize))
          .foregroundColor(Color.amberGold)
      case .checking:
        ProgressView()
          .tint(Color.accentBlue)
          .accessibilityLabel("Checking verification")
      case .verified:
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: iconSize))
          .foregroundColor(Color.successGreen)
      case .error:
        EmptyView()
      }
    }
  }

  private var title: String {
    switch state {
    case .pending:
      return "Email not verified"
    case .checking:
      return "Checking verification..."
    case .verified:
      return "Email verified!"
    case .error:
      return ""
    }
  }

  private var subtitle: String {
    switch state {
    case .pending:
      if let email {
        return "Check \(email) for verification link"
      }
      return "Check your email for a verification link"
    case .checking:
      return "Polling for verification status..."
    case .verified:
      return "You can now access the app"
    case .error:
      return ""
    }
  }

  private var backgroundColor: Color {
    switch state {
    case .pending:
      return Color.amberGold.opacity(0.1)
    case .checking:
      return Color.accentBlue.opacity(0.1)
    case .verified:
      return Color.successGreen.opacity(0.1)
    case .error:
      return Color.clear
    }
  }
}

#Preview {
  VStack(spacing: 16) {
    InfoBanner(state: .pending, email: "test@example.com")
    InfoBanner(state: .checking)
    InfoBanner(state: .verified)
  }
  .padding(16)
}
