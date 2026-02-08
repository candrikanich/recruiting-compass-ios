import SwiftUI

struct QuickTaskWidget: View {
  @Binding var tasks: [QuickTask]
  let onAddTask: (String) -> Void
  let onToggleTask: (String) -> Void
  let onDeleteTask: (String) -> Void
  let onClearCompleted: () -> Void

  @State private var newTaskText = ""
  @FocusState private var isInputFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Quick Tasks")
          .font(.headline)

        Spacer()

        if tasks.contains(where: { $0.isCompleted }) {
          Button("Clear Completed") {
            onClearCompleted()
          }
          .font(.caption)
          .foregroundColor(Color.accentBlue)
        }
      }

      Divider()

      HStack {
        TextField("Add a task...", text: $newTaskText)
          .focused($isInputFocused)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .onSubmit {
            submitTask()
          }

        Button("Add") {
          submitTask()
        }
        .disabled(newTaskText.isEmpty)
      }

      Divider()

      if tasks.isEmpty {
        Text("No tasks yet. Add your first task above!")
          .font(.caption)
          .foregroundColor(Color.secondaryText)
          .padding(.vertical)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(tasks) { task in
              QuickTaskRow(
                task: task,
                onToggle: { onToggleTask(task.id) },
                onDelete: { onDeleteTask(task.id) }
              )
            }
          }
        }
        .frame(maxHeight: 200)
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
  }

  private func submitTask() {
    guard !newTaskText.isEmpty else { return }
    onAddTask(newTaskText)
    newTaskText = ""
    isInputFocused = false
  }
}

struct QuickTaskRow: View {
  let task: QuickTask
  let onToggle: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack {
      Button(action: onToggle) {
        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
          .foregroundColor(task.isCompleted ? Color.successGreen : Color.gray)
      }
      .buttonStyle(PlainButtonStyle())

      Text(task.text)
        .strikethrough(task.isCompleted)
        .foregroundColor(task.isCompleted ? Color.secondaryText : Color.primary)

      Spacer()

      Button(action: onDelete) {
        Image(systemName: "trash")
          .foregroundColor(Color.errorRed)
      }
      .buttonStyle(PlainButtonStyle())
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(task.text)
    .accessibilityValue(task.isCompleted ? "Completed" : "Not completed")
    .accessibilityHint("Double tap to toggle completion")
  }
}

#Preview {
  QuickTaskWidget(
    tasks: .constant([
      QuickTask(text: "Email Coach Smith"),
      QuickTask(text: "Update GPA", isCompleted: true)
    ]),
    onAddTask: { _ in },
    onToggleTask: { _ in },
    onDeleteTask: { _ in },
    onClearCompleted: {}
  )
  .padding()
}
