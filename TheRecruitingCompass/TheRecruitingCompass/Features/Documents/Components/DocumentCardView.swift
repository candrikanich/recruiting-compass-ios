import SwiftUI

struct DocumentCardView: View {
  let document: Document
  let schoolName: String
  let onTap: () -> Void
  let onDelete: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 8) {
        thumbnailSection
        typeBadge
        Text(document.title)
          .font(.subheadline)
          .fontWeight(.medium)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
          .foregroundStyle(.primary)
        metadataRow
        if document.isShared {
          sharedBadge
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(.secondarySystemGroupedBackground))
      .cornerRadius(12)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint("Opens document details")
  }

  private var thumbnailSection: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(.systemGray5))
        .aspectRatio(16/9, contentMode: .fit)

      Image(systemName: iconName)
        .font(.system(size: 40))
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

  private var typeBadge: some View {
    Text("\(document.typeEmoji) \(document.type.label)")
      .font(.caption2)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.blue.opacity(0.2))
      .foregroundStyle(.primary)
      .cornerRadius(6)
  }

  private var metadataRow: some View {
    Text("\(schoolName) • v\(document.version) • \(document.displayDate)")
      .font(.caption)
      .foregroundStyle(.secondary)
      .lineLimit(1)
  }

  private var sharedBadge: some View {
    Text("Shared: \(document.sharedWithSchools.count)")
      .font(.caption2)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Color.green.opacity(0.2))
      .foregroundStyle(.green)
      .cornerRadius(4)
  }

  private var accessibilityLabel: String {
    "\(document.title). \(document.type.label). \(document.isShared ? "Shared with \(document.sharedWithSchools.count) schools. " : "")Uploaded \(document.displayDate)."
  }
}
