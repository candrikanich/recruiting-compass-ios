import SwiftUI

struct DocumentVersionRow: View {
  let version: DocumentVersion
  let onRestore: (DocumentVersion) -> Void

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text("v\(version.version)")
            .font(.subheadline)
            .fontWeight(.semibold)
          if version.isCurrent {
            Text("Current")
              .font(.caption)
              .fontWeight(.semibold)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.accentBlue.opacity(0.2))
              .clipShape(.rect(cornerRadius: 4))
          }
        }
        Text(version.displayDate)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      HStack(spacing: 8) {
        if let url = URL(string: version.fileUrl) {
          Link(destination: url) {
            Text("View")
              .font(.caption)
          }
          .buttonStyle(.bordered)
        }
        if !version.isCurrent {
          Button("Restore") {
            onRestore(version)
          }
          .font(.caption)
          .buttonStyle(.bordered)
          .frame(minHeight: 44)
          .contentShape(Rectangle())
          .accessibilityLabel("Restore version \(version.version)")
          .accessibilityHint("Restores this version as the current document")
        }
      }
    }
    .padding(.vertical, 8)
  }
}
