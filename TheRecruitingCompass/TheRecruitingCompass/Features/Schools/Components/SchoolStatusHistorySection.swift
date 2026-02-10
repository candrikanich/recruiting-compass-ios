import SwiftUI

struct SchoolStatusHistorySection: View {
  let history: [SchoolStatusHistory]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Status History")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      if history.isEmpty {
        Text("No status changes yet")
          .font(.body)
          .foregroundStyle(.secondary)
          .italic()
          .padding(.vertical, 8)
          .accessibilityLabel("Status history empty")
      } else {
        VStack(spacing: 12) {
          ForEach(history) { entry in
            StatusHistoryRow(entry: entry)

            if entry.id != history.last?.id {
              Divider()
                .padding(.vertical, 4)
                .accessibilityHidden(true)
            }
          }
        }
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
}

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
          .font(.caption2)
          .foregroundStyle(.tertiary)

        if let notes = entry.notes, !notes.isEmpty {
          Text(notes)
            .font(.caption2)
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
    var text = "Status changed"
    if let previous = entry.previousStatus {
      text += " from \(previous)"
    }
    text += " to \(entry.newStatus)"
    text += ", \(entry.changedAt.formatted(.relative(presentation: .named)))"
    if let notes = entry.notes, !notes.isEmpty {
      text += ", note: \(notes)"
    }
    return text
  }
}

#Preview {
  ScrollView {
    SchoolStatusHistorySection(history: [
      SchoolStatusHistory(
        id: "1",
        schoolId: "school-1",
        previousStatus: "interested",
        newStatus: "contacted",
        changedBy: "user-1",
        changedAt: Date().addingTimeInterval(-86400 * 2),
        notes: "Emailed coach about official visit",
        createdAt: Date().addingTimeInterval(-86400 * 2)
      ),
      SchoolStatusHistory(
        id: "2",
        schoolId: "school-1",
        previousStatus: "contacted",
        newStatus: "recruited",
        changedBy: "user-1",
        changedAt: Date().addingTimeInterval(-86400),
        notes: nil,
        createdAt: Date().addingTimeInterval(-86400)
      ),
      SchoolStatusHistory(
        id: "3",
        schoolId: "school-1",
        previousStatus: nil,
        newStatus: "interested",
        changedBy: "user-1",
        changedAt: Date().addingTimeInterval(-86400 * 5),
        notes: "Initial contact at showcase",
        createdAt: Date().addingTimeInterval(-86400 * 5)
      )
    ])
    .padding()
  }
}
