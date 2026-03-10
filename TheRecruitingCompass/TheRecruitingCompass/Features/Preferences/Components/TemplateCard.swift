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
          .font(.title2)
          .foregroundStyle(.blue)
          .frame(width: 40)

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.primary)

          Text(description)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(title) template")
    .accessibilityHint(description)
  }
}
