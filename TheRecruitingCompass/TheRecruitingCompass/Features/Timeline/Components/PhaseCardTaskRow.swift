import SwiftUI

struct PhaseCardTaskRow: View {
  let task: TaskWithStatus
  let phaseProgress: Int
  let isViewingAsParent: Bool
  let onCheckboxTap: () -> Void
  let onLockedTap: () -> Void

  @State private var isExpanded = false

  private var isExpandable: Bool { a11y.isExpandable }

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
          .font(.brand(.title3))
          .foregroundStyle(task.statusColor)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .top, spacing: 8) {
          Text(task.title)
            .font(.brand(.subheadline, weight: .medium))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)

          if isExpandable {
            Image(systemName: "chevron.down")
              .font(.brand(.caption, weight: .semibold))
              .foregroundStyle(.tertiary)
              .rotationEffect(.degrees(isExpanded ? 180 : 0))
              .padding(.top, 2)
          }
        }

        badgeRow

        if isExpanded {
          if let description = a11y.visibleDescription {
            Text(description)
              .font(.brand(.footnote))
              .foregroundStyle(.secondary)
          }

          if let why = a11y.visibleWhyItMatters {
            calloutBox(title: String(localized: "Why It Matters"), text: why, color: Color.accentPrimary)
          }

          if let risk = a11y.visibleFailureRisk {
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
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(a11y.label)
    .accessibilityHint(a11y.hint)
    .accessibilityAddTraits(isExpandable ? .isButton : [])
    .accessibilityActions {
      ForEach(a11y.actions, id: \.name) { action in
        Button(action.name) { perform(action) }
      }
    }
  }

  private var a11y: TimelineTaskAccessibility {
    TimelineTaskAccessibility(
      task: task, phaseProgress: phaseProgress, isRecovery: task.athleteTask?.isRecoveryTask == true, isExpanded: isExpanded)
  }

  private func perform(_ action: TimelineTaskAccessibility.Action) {
    switch action {
    case .markComplete: onCheckboxTap()
    case .explainLock: onLockedTap()
    case .showDetails, .hideDetails: withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
    }
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
        Image(systemName: icon).font(.brand(.caption2))
      }
      Text(text).font(.brand(.caption2, weight: .medium))
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
        .font(.brand(.caption2, weight: .bold))
        .foregroundStyle(color)
      Text(text)
        .font(.brand(.caption))
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
}
