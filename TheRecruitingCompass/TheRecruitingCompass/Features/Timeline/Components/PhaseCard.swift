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
          HStack(alignment: .center, spacing: 12) {
            completionIcon

            VStack(alignment: .leading, spacing: 3) {
              HStack(spacing: 8) {
                Text(phase.displayLabel)
                  .font(.brand(.title3, weight: .bold))
                  .foregroundStyle(.primary)
                if isCurrentPhase {
                  currentPhaseBadge
                }
              }
              Text(phase.theme)
                .font(.brand(.subheadline))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 0) {
              Text("\(completedCount)/\(totalCount)")
                .font(.brand(.title3, weight: .semibold))
                .monospacedDigit()
              Text("tasks")
                .font(.brand(.caption2))
                .foregroundStyle(.secondary)
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
              .font(.brand(.caption, weight: .semibold))
              .foregroundStyle(.tertiary)
          }

          HStack(spacing: 8) {
            ProgressView(value: Double(completedCount), total: max(1, Double(totalCount)))
              .tint(isCurrentPhase ? Color.accentPrimary : Color.secondary)
            Text("\(percentComplete)%")
              .font(.brand(.caption, weight: .semibold))
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
        }
        .padding()
      }
      .buttonStyle(.plain)

      if isExpanded, !tasks.isEmpty {
        VStack(spacing: 8) {
          ForEach(tasks) { task in
            PhaseCardTaskRow(
              task: task,
              phaseProgress: percentComplete,
              isViewingAsParent: isViewingAsParent,
              onCheckboxTap: { onTaskCheckboxTap(task.id) },
              onLockedTap: { onLockedTaskTap(task) }
            )
          }
        }
        .padding([.horizontal, .bottom])
        .padding(.top, 4)
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.secondarySystemBackground))
        .overlay {
          RoundedRectangle(cornerRadius: 12)
            .stroke(isCurrentPhase ? Color.accentPrimary.opacity(0.5) : Color.clear, lineWidth: 2)
        }
    )
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(phase.displayLabel), \(completedCount) of \(totalCount) tasks complete"))
    .accessibilityHint("Double tap to expand or collapse")
  }

  @ViewBuilder private var currentPhaseBadge: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(Color.successGreen)
        .frame(width: 6, height: 6)
      Text("Current")
        .font(.brand(.caption2, weight: .semibold))
        .foregroundStyle(Color.successGreen)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(Color.successGreen.opacity(0.12))
    .clipShape(Capsule())
  }

  @ViewBuilder
  private var completionIcon: some View {
    if percentComplete == 100 {
      Image(systemName: "checkmark.circle.fill")
        .font(.brand(.title2))
        .foregroundStyle(Color.successGreen)
    } else if percentComplete > 0 {
      Image(systemName: "circle.lefthalf.filled")
        .font(.brand(.title2))
        .foregroundStyle(Color.accentPrimary)
    } else {
      Image(systemName: "circle")
        .font(.brand(.title2))
        .foregroundStyle(.tertiary)
    }
  }
}
