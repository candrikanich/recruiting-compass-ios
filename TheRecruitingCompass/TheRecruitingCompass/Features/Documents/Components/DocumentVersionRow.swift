import SwiftUI

struct DocumentVersionRow: View {
  let version: DocumentVersion
  let onRestore: (DocumentVersion) -> Void
  var urlResolver: any DocumentURLResolving = DocumentURLResolver()

  @Environment(\.openURL) private var openURL
  @State private var isOpening = false
  @State private var openFailureMessage: String?

  private func openVersion() async {
    isOpening = true
    defer { isOpening = false }
    do {
      openURL(try await urlResolver.openableURL(for: version.fileUrl))
    } catch {
      openFailureMessage = DocumentURLError.openFailureMessage(for: error)
    }
  }

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text("v\(version.version)")
            .font(.brand(.subheadline))
            .fontWeight(.semibold)
          if version.isCurrent {
            Text("Current")
              .font(.brand(.caption))
              .fontWeight(.semibold)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.accentPrimary.opacity(0.2))
              .clipShape(.rect(cornerRadius: 4))
          }
        }
        Text(version.displayDate)
          .font(.brand(.caption))
          .foregroundStyle(.secondary)
      }
      Spacer()
      HStack(spacing: 8) {
        Button {
          Task { await openVersion() }
        } label: {
          Text("View")
            .font(.brand(.caption))
        }
        .buttonStyle(.bordered)
        .disabled(isOpening)
        .accessibilityLabel(String(localized: "View version \(version.version)"))
        if !version.isCurrent {
          Button("Restore") {
            onRestore(version)
          }
          .font(.brand(.caption))
          .buttonStyle(.bordered)
          .frame(minHeight: 44)
          .contentShape(Rectangle())
          .accessibilityLabel(String(localized: "Restore version \(version.version)"))
          .accessibilityHint("Restores this version as the current document")
        }
      }
    }
    .padding(.vertical, 8)
    .alert(
      "Unable to open this version",
      isPresented: Binding(get: { openFailureMessage != nil }, set: { if !$0 { openFailureMessage = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(openFailureMessage ?? "")
    }
  }
}
