import SwiftUI

struct PhaseCard: View {
  let phase: TimelinePhase
  let tasks: [TaskWithStatus]
  let isCurrentPhase: Bool
  let isExpanded: Bool
  let isViewingAsParent: Bool
  let onToggle: () -> Void
  let onTaskCheckboxTap: (String) -> Void
  let onLockedTaskTap: (TaskWithStatus) -> Void

  private var completedCount: Int {
    tasks.count(where: { $0.effectiveStatus == .completed })
  }

  private var totalCount: Int { tasks.count }

  private var percentComplete: Int {
    guard totalCount > 0 else { return 0 }
    return Int(round(Double(completedCount) / Double(totalCount) * 100))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button(action: onToggle) {
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
              Text(phase.displayLabel)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
              Text(phase.theme)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
              completionIcon
              Text("\(completedCount)/\(totalCount)")
                .font(.title3.weight(.semibold))
              Text("tasks")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
          }

          ProgressView(value: Double(completedCount), total: max(1, Double(totalCount)))
            .tint(isCurrentPhase ? Color.accentBlue : Color.secondary)

          if isCurrentPhase {
            HStack(spacing: 6) {
              Circle()
                .fill(Color.successGreen)
                .frame(width: 8, height: 8)
              Text("Current Phase")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.successGreen)
            }
          }
        }
        .padding()
      }
      .buttonStyle(.plain)

      if isExpanded, !tasks.isEmpty {
        Divider()
        VStack(spacing: 0) {
          ForEach(tasks) { task in
            PhaseCardTaskRow(
              task: task,
              isViewingAsParent: isViewingAsParent,
              onCheckboxTap: { onTaskCheckboxTap(task.id) },
              onLockedTap: { onLockedTaskTap(task) }
            )
          }
        }
        .padding()
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.secondarySystemBackground))
        .overlay {
          RoundedRectangle(cornerRadius: 12)
            .stroke(isCurrentPhase ? Color.accentBlue.opacity(0.5) : Color.clear, lineWidth: 2)
        }
    )
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(phase.displayLabel), \(completedCount) of \(totalCount) tasks complete"))
    .accessibilityHint("Double tap to expand or collapse")
  }

  @ViewBuilder
  private var completionIcon: some View {
    if percentComplete == 100 {
      Image(systemName: "checkmark.circle.fill")
        .font(.title2)
        .foregroundStyle(Color.successGreen)
    } else if percentComplete > 0 {
      Image(systemName: "circle.lefthalf.filled")
        .font(.title2)
        .foregroundStyle(Color.accentBlue)
    } else {
      Image(systemName: "circle")
        .font(.title2)
        .foregroundStyle(.tertiary)
    }
  }
}
