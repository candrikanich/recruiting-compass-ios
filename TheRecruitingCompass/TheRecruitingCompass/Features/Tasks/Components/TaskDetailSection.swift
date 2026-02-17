import SwiftUI

struct TaskDetailSection: View {
  let task: TaskWithStatus

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let why = task.whyItMatters, !why.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Why It Matters")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(why)
            .font(.body)
        }
      }

      if let risk = task.failureRisk, !risk.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("What Can Go Wrong")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(risk)
            .font(.body)
        }
      }

      if task.isLocked, !task.prerequisiteTasks.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("Complete These First")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
          ForEach(task.prerequisiteTasks) { pre in
            Text("• \(pre.title)")
              .font(.subheadline)
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.errorRed.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
  }
}

#Preview {
  TaskDetailSection(task: TaskWithStatus(
    id: "1",
    title: "Preview",
    gradeLevel: 10,
    category: "c",
    required: true,
    whyItMatters: "Important for recruiting.",
    failureRisk: "Missing deadline.",
    prerequisiteTasks: [TaskSummary(id: "0", title: "Prereq task")],
    hasIncompletePrerequisites: true
  ))
  .padding()
}
