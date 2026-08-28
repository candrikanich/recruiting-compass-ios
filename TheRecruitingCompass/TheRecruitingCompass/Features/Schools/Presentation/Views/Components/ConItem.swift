import SwiftUI

struct ConItem: View {
  let text: String
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "xmark.circle.fill")
        .foregroundStyle(.red)
        .font(.caption)
        .accessibilityHidden(true)

      Text(text)
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button(action: onRemove) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
          .font(.caption)
          .accessibilityHidden(true)
      }
      .frame(minWidth: 44, minHeight: 44)
      .accessibilityLabel(String(localized: "Remove con: \(text)"))
      .accessibilityHint("Double tap to remove this con")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.red.opacity(0.1))
    .clipShape(.rect(cornerRadius: 8))
  }
}
