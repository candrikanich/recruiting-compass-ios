import SwiftUI

struct PhaseCardTaskRow: View {
  let task: TaskWithStatus
  let isViewingAsParent: Bool
  let onCheckboxTap: () -> Void
  let onLockedTap: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Button {
        if task.isLocked {
          onLockedTap()
        } else {
          onCheckboxTap()
        }
      } label: {
        Image(systemName: task.effectiveStatus == .completed ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(task.effectiveStatus == .completed ? Color.successGreen : .secondary)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .disabled(isViewingAsParent)
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 4) {
        if task.isLocked {
          Text("Locked")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.2))
            .clipShape(Capsule())
        }
        Text(task.title)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.primary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(task.title), \(task.effectiveStatus.displayName)"))
    .accessibilityHint(task.isLocked ? "Locked until prerequisites complete" : "Double tap to mark complete")
  }
}
