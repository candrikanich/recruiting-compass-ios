import SwiftUI

struct ProItem: View {
  let text: String
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
        .font(.brand(.caption))
        .accessibilityHidden(true)

      Text(text)
        .font(.brand(.body))
        .frame(maxWidth: .infinity, alignment: .leading)

      Button(action: onRemove) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
          .font(.brand(.caption))
      }
      .frame(minWidth: 44, minHeight: 44)
      .accessibilityLabel(String(localized: "Remove \(text)"))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.green.opacity(0.1))
    .clipShape(.rect(cornerRadius: 8))
  }
}
