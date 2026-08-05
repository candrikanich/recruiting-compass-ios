import SwiftUI

struct StatusHistoryRow: View {
  let entry: SchoolStatusHistory

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "arrow.right.circle.fill")
        .foregroundStyle(.blue)
        .font(.title3)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          if let previous = entry.previousStatus {
            Text(previous)
              .font(.caption)
              .foregroundStyle(.secondary)
              .strikethrough()
          }

          Image(systemName: "arrow.right")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

          Text(entry.newStatus)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
        }

        Text(entry.changedAt, style: .relative)
          .font(.caption)
          .foregroundStyle(.tertiary)

        if let notes = entry.notes, !notes.isEmpty {
          Text(notes)
            .font(.caption)
            .foregroundStyle(.secondary)
            .italic()
            .padding(.top, 2)
        }
      }

      Spacer()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityText)
  }

  private var accessibilityText: String {
    var text = String(localized: "Status changed")
    if let previous = entry.previousStatus {
      text += String(localized: " from \(previous)")
    }
    text += String(localized: " to \(entry.newStatus)")
    text += String(localized: ", \(entry.changedAt.formatted(.relative(presentation: .named)))")
    if let notes = entry.notes, !notes.isEmpty {
      text += String(localized: ", note: \(notes)")
    }
    return text
  }
}
