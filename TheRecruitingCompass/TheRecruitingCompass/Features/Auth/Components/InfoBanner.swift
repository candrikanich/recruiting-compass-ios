import SwiftUI

struct InfoBanner: View {
  let state: BannerState
  @State private var isVisible = true
  @Environment(\.sizeCategory) var sizeCategory

  enum BannerState {
    case pending(email: String)
    case checking
    case verified
  }

  private var iconSize: CGFloat {
    sizeCategory >= .extraLarge ? 22 : 20
  }

  var body: some View {
    if isVisible {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 12) {
          icon
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 4) {
            Text(title)
              .font(.footnote.weight(.semibold))
            Text(subtitle)
              .font(.caption)
              .foregroundColor(subtitleColor)
          }
          Spacer()
        }
        .padding(12)
      }
      .background(backgroundColor)
      .cornerRadius(8)
      .transition(.opacity)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(title)
      .accessibilityValue(subtitle)
      .accessibilityAddTraits(.isHeader)
    }
  }

  // MARK: - Private Properties

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
    }
  }

  private var subtitle: String {
    switch state {
    case .pending(let email):
      return "Check \(email) for verification link"
    case .checking:
      return "Polling for verification status..."
    case .verified:
      return "You can now access the app"
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
    }
  }

  private var subtitleColor: Color {
    switch state {
    case .pending:
      return Color.secondaryText
    case .checking:
      return Color.secondaryText
    case .verified:
      return Color.secondaryText
    }
  }

  // MARK: - Static Factories

  static func pending(email: String) -> InfoBanner {
    InfoBanner(state: .pending(email: email))
  }

  static func checking() -> InfoBanner {
    InfoBanner(state: .checking)
  }

  static func verified() -> InfoBanner {
    InfoBanner(state: .verified)
  }
}

#Preview {
  VStack(spacing: 16) {
    InfoBanner.pending(email: "test@example.com")
    InfoBanner.checking()
    InfoBanner.verified()
  }
  .padding(16)
}
