import SwiftUI

struct TemplateCard: View {
  let title: String
  let description: String
  let icon: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.brand(.title2))
          .foregroundStyle(Color.accentPrimary)
          .frame(width: 40)

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.brand(.subheadline))
            .fontWeight(.medium)
            .foregroundStyle(.primary)

          Text(description)
            .font(.brand(.caption))
            .foregroundStyle(.secondary)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.brand(.caption))
          .foregroundStyle(.secondary)
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(String(localized: "\(title) template"))
    .accessibilityHint(description)
  }
}
