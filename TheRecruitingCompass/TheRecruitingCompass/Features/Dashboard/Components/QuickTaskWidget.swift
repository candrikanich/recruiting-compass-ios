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
          .accessibilityAddTraits(.isHeader)

        Spacer()

        if tasks.contains(where: { $0.isCompleted }) {
          Button("Clear Completed") {
            onClearCompleted()
          }
          .font(.caption)
          .foregroundStyle(Color.accentBlue)
          .accessibilityLabel(String(localized: "Clear completed tasks"))
          .accessibilityHint("Removes all completed tasks from the list")
        }
      }

      Divider()

      HStack {
        TextField("Add a task...", text: $newTaskText)
          .focused($isInputFocused)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .accessibilityLabel(String(localized: "New task"))
          .accessibilityHint("Type a task name, then press return or tap Add")
          .onSubmit {
            submitTask()
          }

        Button("Add") {
          submitTask()
        }
        .disabled(newTaskText.isEmpty)
        .accessibilityLabel(String(localized: "Add task"))
        .accessibilityHint("Adds the typed task to your list")
      }

      Divider()

      if tasks.isEmpty {
        Text("No tasks yet. Add your first task above!")
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
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
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }

  private func submitTask() {
    guard !newTaskText.isEmpty else { return }
    onAddTask(newTaskText)
    newTaskText = ""
    isInputFocused = false
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
