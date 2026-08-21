import SwiftUI

struct PhaseCardTaskRow: View {
  let task: TaskWithStatus
  let phaseProgress: Int
  let isViewingAsParent: Bool
  let onCheckboxTap: () -> Void
  let onLockedTap: () -> Void

  @State private var isExpanded = false

  private var isCompleted: Bool { task.effectiveStatus == .completed }

  /// Web parity (`components/Timeline/TaskItem.vue`): the failure-risk callout
  /// only surfaces as a phase nears completion, not on every open task.
  private var showFailureRisk: Bool { !isCompleted && phaseProgress >= 75 }

  private var hasDescription: Bool {
    (task.description?.isEmpty == false)
  }

  private var hasWhy: Bool {
    (task.whyItMatters?.isEmpty == false) && !isCompleted
  }

  private var hasRisk: Bool {
    (task.failureRisk?.isEmpty == false) && showFailureRisk
  }

  /// Whether the row has any collapsible detail worth a tap.
  private var isExpandable: Bool { hasDescription || hasWhy || hasRisk }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Button {
        if task.isLocked {
          onLockedTap()
        } else {
          onCheckboxTap()
        }
      } label: {
        Image(systemName: task.statusIconName)
          .font(.title3)
          .foregroundStyle(task.statusColor)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .top, spacing: 8) {
          Text(task.title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)

          if isExpandable {
            Image(systemName: "chevron.down")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.tertiary)
              .rotationEffect(.degrees(isExpanded ? 180 : 0))
              .padding(.top, 2)
          }
        }

        badgeRow

        if isExpanded {
          if let description = task.description, !description.isEmpty {
            Text(description)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }

          if hasWhy, let why = task.whyItMatters {
            calloutBox(title: String(localized: "Why It Matters"), text: why, color: Color.accentBlue)
          }

          if hasRisk, let risk = task.failureRisk {
            calloutBox(title: String(localized: "Don't Miss This"), text: risk, color: Color.amberGold)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(Color(.tertiarySystemBackground))
    )
    .contentShape(RoundedRectangle(cornerRadius: 10))
    .onTapGesture {
      guard isExpandable else { return }
      withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(accessibilityHint)
    .accessibilityAddTraits(isExpandable ? .isButton : [])
  }

  @ViewBuilder
  private var badgeRow: some View {
    HStack(spacing: 6) {
      if task.isLocked {
        badge(String(localized: "Locked"), color: .orange)
      }
      if task.athleteTask?.isRecoveryTask == true {
        badge(String(localized: "Recovery"), color: Color.Brand.orange600, icon: "arrow.clockwise")
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

  private func calloutBox(title: String, text: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption2.weight(.bold))
        .foregroundStyle(color)
      Text(text)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(color.opacity(0.08))
    .overlay(alignment: .leading) {
      Rectangle().fill(color).frame(width: 3)
    }
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  private var accessibilityLabel: String {
    var parts = [task.title, task.categoryLabel]
    if task.required { parts.append(String(localized: "Required")) }
    parts.append(task.effectiveStatus.displayName)
    return parts.joined(separator: ", ")
  }

  private var accessibilityHint: String {
    if task.isLocked {
      return String(localized: "Locked until prerequisites complete")
    }
    if isExpandable {
      return isExpanded
        ? String(localized: "Double tap to collapse details")
        : String(localized: "Double tap to show details")
    }
    return String(localized: "Double tap to mark complete")
  }
}
