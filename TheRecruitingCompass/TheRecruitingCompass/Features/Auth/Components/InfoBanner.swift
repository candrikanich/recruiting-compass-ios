import SwiftUI

struct InfoBanner: View {
  let state: VerificationState
  let email: String?
  @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 20

  init(state: VerificationState, email: String? = nil) {
    self.state = state
    self.email = email
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

  @ViewBuilder
  private var icon: some View {
    switch state {
    case .pending:
      Image(systemName: "envelope.fill")
        .font(.system(size: iconSize))
        .foregroundStyle(Color.amberGold)
    case .checking:
      ProgressView()
        .tint(Color.accentBlue)
        .accessibilityLabel(String(localized: "Checking verification"))
    case .verified:
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: iconSize))
        .foregroundStyle(Color.successGreen)
    case .error:
      EmptyView()
    }
  }

  private var title: String {
    switch state {
    case .pending:
      return String(localized: "Email not verified")
    case .checking:
      return String(localized: "Checking verification...")
    case .verified:
      return String(localized: "Email verified!")
    case .error:
      return ""
    }
  }

  private var subtitle: String {
    switch state {
    case .pending:
      if let email {
        return String(localized: "Check \(email) for verification link")
      }
      return String(localized: "Check your email for a verification link")
    case .checking:
      return String(localized: "Polling for verification status...")
    case .verified:
      return String(localized: "You can now access the app")
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
