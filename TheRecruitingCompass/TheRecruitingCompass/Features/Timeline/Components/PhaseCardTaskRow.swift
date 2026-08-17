import SwiftUI

struct PhaseCardTaskRow: View {
  let task: TaskWithStatus
  let isViewingAsParent: Bool
  let onCheckboxTap: () -> Void
  let onLockedTap: () -> Void

  private var isCompleted: Bool { task.effectiveStatus == .completed }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Button {
        if task.isLocked {
          onLockedTap()
        } else {
          onCheckboxTap()
        }
      } label: {
        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isCompleted ? Color.successGreen : .secondary)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 6) {
        Text(task.title)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.primary)

        if let description = task.description, !description.isEmpty {
          Text(description)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        badgeRow

        if let why = task.whyItMatters, !why.isEmpty, !isCompleted {
          whyItMattersCallout(why)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(task.isLocked ? "Locked until prerequisites complete" : "Double tap to mark complete")
  }

  @ViewBuilder
  private var badgeRow: some View {
    HStack(spacing: 6) {
      if task.isLocked {
        badge(String(localized: "Locked"), color: .orange)
      }
      if let urgency = deadlineBadge {
        badge(urgency.text, color: urgency.color, icon: urgency.icon)
      }
      badge(task.categoryLabel, color: task.categoryColor)
      if task.required {
        badge(String(localized: "Required"), color: .errorRed)
      }
    }
  }

  private var deadlineBadge: (text: String, color: Color, icon: String?)? {
    guard task.deadlineDate != nil else { return nil }
    let urgency = task.deadlineUrgency
    guard let label = urgency.label else { return nil }
    return (label, urgency.color, urgency.iconName)
  }

  private func badge(_ text: String, color: Color, icon: String? = nil) -> some View {
    HStack(spacing: 3) {
      if let icon {
        Image(systemName: icon).font(.caption2)
      }
      Text(text).font(.caption2.weight(.medium))
    }
    .foregroundStyle(color)
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(color.opacity(0.15))
    .clipShape(Capsule())
    .accessibilityHidden(true)
  }

  private func whyItMattersCallout(_ text: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("Why It Matters")
        .font(.caption2.weight(.bold))
        .foregroundStyle(Color.accentBlue)
      Text(text)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(Color.accentBlue.opacity(0.08))
    .overlay(alignment: .leading) {
      Rectangle().fill(Color.accentBlue).frame(width: 3)
    }
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  private var accessibilityLabel: String {
    var parts = [task.title, task.categoryLabel]
    if task.required { parts.append(String(localized: "Required")) }
    parts.append(task.effectiveStatus.displayName)
    return parts.joined(separator: ", ")
  }
}
