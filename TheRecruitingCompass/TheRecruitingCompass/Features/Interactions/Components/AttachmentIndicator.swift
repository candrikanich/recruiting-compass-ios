import SwiftUI

struct AttachmentIndicator: View {
  let count: Int

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "paperclip")
        .font(.caption)
        .accessibilityHidden(true)

      Text("\(count)")
        .font(.caption)
        .fontWeight(.medium)
    }
    .foregroundStyle(.secondary)
    .accessibilityLabel(accessibilityLabel)
  }

  var accessibilityLabel: String {
    "\(count) attachment\(count == 1 ? "" : "s")"
  }
}
