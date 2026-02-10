import SwiftUI

struct SchoolDocumentsSection: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Documents", systemImage: "doc.fill")
          .font(.headline)
          .foregroundStyle(.primary)

        Spacer()

        Button(action: {}) {
          HStack(spacing: 4) {
            Text("Upload")
              .font(.subheadline)

            Text("Coming Soon")
              .font(.caption2)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.amberGold.opacity(0.2))
              .foregroundStyle(Color.amberGold)
              .cornerRadius(4)
          }
          .foregroundStyle(.secondary)
        }
        .disabled(true)
        .accessibilityLabel("Upload documents")
        .accessibilityHint("This feature is coming soon")
      }

      DocumentsEmptyState()
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
  }
}

private struct DocumentsEmptyState: View {
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.text")
        .font(.system(size: 48))
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
    .accessibilityLabel("No documents. Document upload feature coming soon")
  }
}

#Preview {
  SchoolDocumentsSection()
    .padding()
}
