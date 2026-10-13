import Foundation

/// Pure VoiceOver description of a Timeline phase header; kept out of the views so it is unit-testable.
struct PhaseCardAccessibility {
  let phaseLabel: String
  let completed: Int
  let total: Int
  let isExpanded: Bool

  var label: String {
    String(localized: "\(phaseLabel), \(completed) of \(total) tasks complete")
  }

  var value: String {
    isExpanded ? String(localized: "Expanded") : String(localized: "Collapsed")
  }

  var hint: String {
    isExpanded
      ? String(localized: "Double tap to hide tasks")
      : String(localized: "Double tap to show tasks")
  }
}

/// Pure VoiceOver description of a Timeline task row.
struct TimelineTaskAccessibility {
  enum Action: Equatable {
    case markComplete, showDetails, hideDetails, explainLock

    var name: String {
      switch self {
      case .markComplete: return String(localized: "Mark complete")
      case .showDetails: return String(localized: "Show details")
      case .hideDetails: return String(localized: "Hide details")
      case .explainLock: return String(localized: "Why is this locked?")
      }
    }
  }

  let task: TaskWithStatus
  let phaseProgress: Int
  let isRecovery: Bool
  let isExpanded: Bool

  private var isCompleted: Bool { task.effectiveStatus == .completed }

  /// Web parity (`components/Timeline/TaskItem.vue`): the failure-risk callout
  /// only surfaces as a phase nears completion, not on every open task.
  private var showsFailureRisk: Bool { !isCompleted && phaseProgress >= 75 }

  /// Single source of truth for which detail text the row can reveal; the view renders these same values.
  var visibleDescription: String? { task.description.flatMap { $0.isEmpty ? nil : $0 } }

  var visibleWhyItMatters: String? {
    isCompleted ? nil : task.whyItMatters.flatMap { $0.isEmpty ? nil : $0 }
  }

  var visibleFailureRisk: String? {
    showsFailureRisk ? task.failureRisk.flatMap { $0.isEmpty ? nil : $0 } : nil
  }

  var isExpandable: Bool {
    visibleDescription != nil || visibleWhyItMatters != nil || visibleFailureRisk != nil
  }

  var label: String {
    var parts = [task.title, task.effectiveStatus.displayName]
    if task.isLocked { parts.append(String(localized: "Locked")) }
    if isRecovery { parts.append(String(localized: "Recovery")) }
    if task.deadlineDate != nil, let urgency = task.deadlineUrgency.label { parts.append(urgency) }
    parts.append(task.categoryLabel)
    if task.required { parts.append(String(localized: "Required")) }
    if isExpanded { parts.append(contentsOf: detailText) }
    return parts.joined(separator: ", ")
  }

  private var detailText: [String] {
    [
      visibleDescription,
      visibleWhyItMatters.map { "\(String(localized: "Why It Matters")): \($0)" },
      visibleFailureRisk.map { "\(String(localized: "Don't Miss This")): \($0)" }
    ].compactMap { $0 }
  }

  var hint: String {
    if task.isLocked { return String(localized: "Locked until prerequisites complete") }
    guard !actions.isEmpty else { return "" }
    let names = actions.map(\.name).joined(separator: ", ")
    return String(localized: "Actions available: \(names)")
  }

  var actions: [Action] {
    if task.isLocked { return [.explainLock] }
    var actions: [Action] = []
    if !isCompleted { actions.append(.markComplete) }
    if isExpandable { actions.append(isExpanded ? .hideDetails : .showDetails) }
    return actions
  }
}
