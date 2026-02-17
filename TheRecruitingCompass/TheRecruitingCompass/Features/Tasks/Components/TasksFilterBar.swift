import SwiftUI

struct TasksFilterBar: View {
  @Binding var statusFilter: TaskStatusFilter
  @Binding var urgencyFilter: TaskUrgencyFilter

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 12) {
        Picker("Status", selection: $statusFilter) {
          ForEach(TaskStatusFilter.allCases, id: \.self) { filter in
            Text(filter.displayName).tag(filter)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Filter by status")
        .accessibilityHint("Double tap to choose status filter")

        Picker("Urgency", selection: $urgencyFilter) {
          ForEach(TaskUrgencyFilter.allCases, id: \.self) { filter in
            Text(filter.displayName).tag(filter)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Filter by urgency")
        .accessibilityHint("Double tap to choose urgency filter")
      }
    }
    .padding(.horizontal, 16)
  }
}

#Preview {
  TasksFilterBar(statusFilter: .constant(.all), urgencyFilter: .constant(.all))
}
