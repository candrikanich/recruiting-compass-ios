import SwiftUI

struct QuickTaskRow: View {
  let task: QuickTask
  let onToggle: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack {
      Button(action: onToggle) {
        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(task.isCompleted ? Color.successGreen : Color.gray)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(String(localized: "Task: \(task.text)"))
      .accessibilityValue(task.isCompleted ? "Completed" : "Not completed")
      .accessibilityHint("Double tap to toggle completion")

      Text(task.text)
        .strikethrough(task.isCompleted)
        .foregroundStyle(task.isCompleted ? Color.secondaryText : Color.primary)
        .accessibilityHidden(true)

      Spacer()

      Button(action: onDelete) {
        Image(systemName: "trash")
          .foregroundStyle(Color.errorRed)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(String(localized: "Delete task: \(task.text)"))
      .accessibilityHint("Permanently removes this task")
    }
  }
}
