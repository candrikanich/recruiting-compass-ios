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
        LazyVStack(spacing: 12) {
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
    .clipShape(.rect(cornerRadius: 12))
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
        changedAt: Date.now.addingTimeInterval(-86400 * 2),
        notes: "Emailed coach about official visit",
        createdAt: Date.now.addingTimeInterval(-86400 * 2)
      ),
      SchoolStatusHistory(
        id: "2",
        schoolId: "school-1",
        previousStatus: "contacted",
        newStatus: "recruited",
        changedBy: "user-1",
        changedAt: Date.now.addingTimeInterval(-86400),
        notes: nil,
        createdAt: Date.now.addingTimeInterval(-86400)
      ),
      SchoolStatusHistory(
        id: "3",
        schoolId: "school-1",
        previousStatus: nil,
        newStatus: "interested",
        changedBy: "user-1",
        changedAt: Date.now.addingTimeInterval(-86400 * 5),
        notes: "Initial contact at showcase",
        createdAt: Date.now.addingTimeInterval(-86400 * 5)
      )
    ])
    .padding()
  }
}
