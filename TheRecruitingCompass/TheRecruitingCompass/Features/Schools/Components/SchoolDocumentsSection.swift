import SwiftUI

struct SchoolDocumentsSection: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Documents", systemImage: "doc")
          .font(.headline)
          .foregroundStyle(.primary)

        Spacer()

        Button(action: {}) {
          HStack(spacing: 4) {
            Text("Upload")
              .font(.subheadline)

            Text("Coming Soon")
              .font(.caption)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.amberGold.opacity(0.2))
              .foregroundStyle(Color.amberGold)
              .clipShape(.rect(cornerRadius: 4))
          }
          .foregroundStyle(.secondary)
        }
        .disabled(true)
        .accessibilityLabel(String(localized: "Upload documents"))
        .accessibilityHint("This feature is coming soon")
      }

      DocumentsEmptyState()
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowMd()
  }
}

private struct DocumentsEmptyState: View {
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.text")
        .font(.largeTitle)
        .imageScale(.large)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("No Documents")
        .font(.headline)
        .foregroundStyle(.secondary)

      Text("Document upload feature coming soon")
        .font(.subheadline)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "No documents"))
    .accessibilityHint("Document upload feature is coming soon")
  }
}

#Preview {
  SchoolDocumentsSection()
    .padding()
}
