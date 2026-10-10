import SwiftUI

struct AttachmentIndicator: View {
  let count: Int

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "paperclip")
        .font(.brand(.caption))
        .accessibilityHidden(true)

      Text("\(count)")
        .font(.brand(.caption))
        .fontWeight(.medium)
    }
    .foregroundStyle(.secondary)
    .accessibilityLabel(accessibilityLabel)
  }

  var accessibilityLabel: String {
    String(localized: "\(count) attachment\(count == 1 ? "" : "s")")
  }
}
