import SwiftUI

struct TaskCard: View {
  let task: TaskWithStatus
  let isExpanded: Bool
  let isViewingAsParent: Bool
  let onToggleExpand: () -> Void
  let onCheckboxTap: () -> Void
  let onLockedCheckboxTap: (() -> Void)?

  @Environment(\.sizeCategory) private var sizeCategory

  private var checkboxIconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 26 : 22
  }

  private var checkboxAccessibilityLabel: String {
    if task.isLocked {
      let prereqs = task.prerequisiteTasks.map(\.title).joined(separator: ", ")
      return String(localized: "Complete \(prereqs) to unlock")
    }
    return String(localized: "Mark \(task.title) complete")
  }

  private var cardAccessibilityLabel: String {
    let status = task.effectiveStatus.displayName
    let locked = task.isLocked ? "Locked" : "Unlocked"
    let req = task.required ? "Required" : "Optional"
    return String(localized: "\(task.title), \(status), \(locked), \(req)")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Button {
          if task.isLocked {
            onLockedCheckboxTap?()
          } else {
            onCheckboxTap()
          }
        } label: {
          Image(systemName: task.effectiveStatus == .completed ? "checkmark.circle.fill" : "circle")
            .font(.system(size: checkboxIconSize))
            .foregroundStyle(task.effectiveStatus == .completed ? Color.successGreen : .secondary)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(isViewingAsParent)
        .buttonStyle(.plain)
        .accessibilityLabel(checkboxAccessibilityLabel)
        .accessibilityHint(task.isLocked ? "Double tap to see prerequisites" : "Double tap to mark complete")

        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 6) {
            if task.isLocked {
              Text("Locked")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .clipShape(Capsule())
                .accessibilityHidden(true)
            }
            if task.required {
              Text("Required")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentBlue.opacity(0.2))
                .clipShape(Capsule())
                .accessibilityHidden(true)
            }
            HStack(spacing: 3) {
              Image(systemName: task.statusIconName)
                .font(.caption2)
                .accessibilityHidden(true)
              Text(task.effectiveStatus.displayName)
            }
            .font(.caption)
            .foregroundStyle(task.statusColor)
          }

          Text(task.title)
            .font(.headline)
            .foregroundStyle(.primary)

          if let desc = task.description, !desc.isEmpty {
            Text(desc)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(isExpanded ? nil : 2)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }
      .contentShape(Rectangle())
      .onTapGesture { onToggleExpand() }

      if isExpanded {
        TaskDetailSection(task: task)
      }
    }
    .padding()
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(cardAccessibilityLabel)
    .accessibilityHint("Double tap to expand or collapse")
  }
}

#Preview {
  TaskCard(
    task: TaskWithStatus(id: "1", title: "Complete profile", gradeLevel: 10, category: "c", required: true, hasIncompletePrerequisites: false),
    isExpanded: false,
    isViewingAsParent: false,
    onToggleExpand: {},
    onCheckboxTap: {},
    onLockedCheckboxTap: nil
  )
  .padding()
}
