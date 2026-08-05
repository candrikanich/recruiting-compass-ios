import SwiftUI

struct DocumentHeaderCard: View {
  let document: Document
  let onEdit: () -> Void
  let onShare: () -> Void
  let onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          Text("\(document.typeEmoji) \(document.typeLabel)")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentBlue.opacity(0.2))
            .foregroundStyle(.primary)
            .clipShape(.rect(cornerRadius: 6))
          Text(document.title)
            .font(.title2)
            .bold()
            .lineLimit(2)
            .truncationMode(.tail)
          if let desc = document.description, !desc.isEmpty {
            Text(desc)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()
      }
      HStack(spacing: 12) {
        Button(action: onEdit) {
          Label("Edit", systemImage: "pencil")
            .font(.subheadline.weight(.medium))
            .frame(minWidth: 88, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentBlue)
        .accessibilityLabel(String(localized: "Edit document metadata"))

        Button(action: onShare) {
          Label("Share", systemImage: "square.and.arrow.up")
            .font(.subheadline.weight(.medium))
            .frame(minWidth: 88, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.primaryGreen)
        .accessibilityLabel(String(localized: "Share document with schools"))

        Button(role: .destructive, action: onDelete) {
          Label("Delete", systemImage: "trash")
            .font(.subheadline.weight(.medium))
            .frame(minWidth: 88, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.errorRed)
        .accessibilityLabel(String(localized: "Delete document"))
        .accessibilityHint("This action cannot be undone")
      }
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(.rect(cornerRadius: 12))
  }
}
