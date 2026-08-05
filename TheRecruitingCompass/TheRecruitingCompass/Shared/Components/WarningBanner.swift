import SwiftUI

/// A reusable warning banner component for displaying informational warnings.
struct WarningBanner: View {
  let title: String
  let message: String
  let color: Color

  init(title: String, message: String, color: Color = .orange) {
    self.title = title
    self.message = message
    self.color = color
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(color)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.subheadline)
          .fontWeight(.semibold)

        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(12)
    .background(color.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "Warning: \(title). \(message)"))
  }
}

#Preview {
  VStack(spacing: 16) {
    WarningBanner(
      title: "Large School List",
      message: "You're tracking 45 schools. Consider using filters to focus on your top choices."
    )

    WarningBanner(
      title: "Sync Issue",
      message: "Some data may be out of date.",
      color: .red
    )

    WarningBanner(
      title: "Info",
      message: "This is an informational message.",
      color: .blue
    )
  }
  .padding()
}
