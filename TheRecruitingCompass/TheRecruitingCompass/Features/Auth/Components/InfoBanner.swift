import SwiftUI

struct InfoBanner: View {
  let state: BannerState
  @State private var isVisible = true

  enum BannerState {
    case pending(email: String)
    case checking
    case verified
  }

  var body: some View {
    if isVisible {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 12) {
          icon
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 4) {
            Text(title)
              .font(.system(size: 14, weight: .semibold))
            Text(subtitle)
              .font(.system(size: 12, weight: .regular))
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
          .font(.system(size: 20))
          .foregroundColor(Color(red: 0.855, green: 0.620, blue: 0.118))
      case .checking:
        ProgressView()
          .tint(Color(red: 0.149, green: 0.388, blue: 0.931))
          .accessibilityLabel("Checking verification")
      case .verified:
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 20))
          .foregroundColor(Color(red: 0.2, green: 0.62, blue: 0.4))
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
      return Color(red: 0.855, green: 0.620, blue: 0.118).opacity(0.1)
    case .checking:
      return Color(red: 0.149, green: 0.388, blue: 0.931).opacity(0.1)
    case .verified:
      return Color(red: 0.2, green: 0.62, blue: 0.4).opacity(0.1)
    }
  }

  private var subtitleColor: Color {
    switch state {
    case .pending:
      return Color(red: 0.427, green: 0.467, blue: 0.514)
    case .checking:
      return Color(red: 0.427, green: 0.467, blue: 0.514)
    case .verified:
      return Color(red: 0.427, green: 0.467, blue: 0.514)
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
