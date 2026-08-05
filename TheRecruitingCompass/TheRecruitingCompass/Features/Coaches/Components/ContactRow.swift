import SwiftUI

/// A reusable row component for displaying contact information with optional link.
struct ContactRow: View {
  let icon: String
  let label: String
  let value: String
  let type: CommunicationType
  /// When set, row is a button that runs this action instead of opening the type's URL (e.g. to show Quick Communication).
  var customAction: (() -> Void)?

  var body: some View {
    Group {
      if let customAction {
        Button(action: customAction) {
          rowContent(showLinkIndicator: true)
        }
        .accessibilityLabel(String(localized: "\(label): \(value)"))
        .accessibilityHint("Opens Quick Communication with templates")
      } else if let url = type.url(for: value) {
        Link(destination: url) {
          rowContent(showLinkIndicator: true)
        }
        .accessibilityLabel(String(localized: "\(label): \(value)"))
        .accessibilityHint("Opens \(type.appName)")
      } else {
        rowContent(showLinkIndicator: false)
          .accessibilityLabel(String(localized: "\(label): \(value)"))
      }
    }
  }

  private func rowContent(showLinkIndicator: Bool) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.body)
        .foregroundStyle(type.url(for: value) != nil || customAction != nil ? type.iconColor : .secondary)
        .frame(width: 24)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(label)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.body)
          .foregroundStyle(.primary)
      }

      Spacer()

      if showLinkIndicator {
        Image(systemName: "arrow.up.right")
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }
    }
  }
}

#Preview {
  VStack(spacing: 16) {
    ContactRow(
      icon: "envelope",
      label: "Email",
      value: "coach@example.com",
      type: .email("coach@example.com")
    )

    ContactRow(
      icon: "phone",
      label: "Phone",
      value: "555-0123",
      type: .phone("555-0123")
    )

    ContactRow(
      icon: "at",
      label: "Twitter",
      value: "@coach",
      type: .twitter("@coach")
    )

    ContactRow(
      icon: "camera",
      label: "Instagram",
      value: "@coach",
      type: .instagram("@coach")
    )
  }
  .padding()
}
