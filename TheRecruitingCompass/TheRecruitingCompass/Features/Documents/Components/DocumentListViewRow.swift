import SwiftUI

struct DocumentListViewRow: View {
  let document: Document
  let schoolName: String
  let onTap: () -> Void
  let onDelete: () -> Void

  var deleteAccessibilityLabel: String { "Delete \(document.title)" }

  var body: some View {
    HStack(spacing: 0) {
      Button(action: onTap) {
        HStack(spacing: 12) {
          thumbnailView
          contentView
          if document.isShared {
            Text("Shared: \(document.sharedWithSchools.count)")
              .font(.caption)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.green.opacity(0.2))
              .foregroundStyle(.green)
              .clipShape(.rect(cornerRadius: 4))
          }
        }
        .padding(12)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityHint("Opens document details")

      deleteButton
        .padding(.trailing, 12)
    }
  }

  @ViewBuilder
  private var deleteButton: some View {
    Button(role: .destructive) {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      onDelete()
    } label: {
      Image(systemName: "trash")
        .font(.subheadline)
        .foregroundStyle(Color.errorRed)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
    .accessibilityLabel(deleteAccessibilityLabel)
    .accessibilityHint("Double tap to delete this document")
  }

  @ViewBuilder
  private var thumbnailView: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(.systemGray5))
        .frame(width: 80, height: 60)

      Image(systemName: iconName)
        .font(.title2)
        .foregroundStyle(.secondary)
    }
  }

  private var iconName: String {
    switch document.type {
    case .highlightVideo: return "video.fill"
    case .transcript, .resume, .recLetter, .questionnaire: return "doc.fill"
    case .statsSheet: return "tablecells.fill"
    }
  }

  @ViewBuilder
  private var contentView: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(document.title)
        .font(.subheadline)
        .fontWeight(.medium)
        .lineLimit(1)
        .foregroundStyle(.primary)
      Text("\(schoolName) • v\(document.version) • \(document.displayDate)")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var accessibilityLabel: String {
    "\(document.title). \(document.type.label). \(document.isShared ? "Shared with \(document.sharedWithSchools.count) schools. " : "")Uploaded \(document.displayDate)."
  }
}
