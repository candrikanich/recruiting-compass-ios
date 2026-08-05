import SwiftUI

struct FormatOptionCard: View {
  let format: ExportFormat
  let isSelected: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 16) {
        Image(systemName: format.icon)
          .font(.title2)
          .foregroundStyle(isSelected ? Color.accentBlue : .secondary)
          .frame(width: 40)

        VStack(alignment: .leading, spacing: 4) {
          Text(format.rawValue)
            .font(.headline)
            .foregroundStyle(.primary)

          Text(format.description)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.accentBlue)
        }
      }
      .padding()
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isSelected ? Color.accentBlue.opacity(0.1) : Color(.systemGray6))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(isSelected ? Color.accentBlue : Color.clear, lineWidth: 2)
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(String(localized: "\(format.rawValue) format, \(format.description)"))
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }
}
