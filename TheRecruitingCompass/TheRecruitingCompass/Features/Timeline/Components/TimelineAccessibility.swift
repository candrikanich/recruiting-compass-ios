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
  let isRecovery: Bool
  let isExpanded: Bool

  private var isCompleted: Bool { task.effectiveStatus == .completed }

  private var hasDetails: Bool {
    let hasText = { (text: String?) in text?.isEmpty == false }
    return hasText(task.description) || (hasText(task.whyItMatters) && !isCompleted)
      || (hasText(task.failureRisk) && !isCompleted)
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
    var details: [String] = []
    if let description = task.description, !description.isEmpty { details.append(description) }
    if !isCompleted, let why = task.whyItMatters, !why.isEmpty {
      details.append("\(String(localized: "Why It Matters")): \(why)")
    }
    if !isCompleted, let risk = task.failureRisk, !risk.isEmpty {
      details.append("\(String(localized: "Don't Miss This")): \(risk)")
    }
    return details
  }

  var hint: String {
    if task.isLocked { return String(localized: "Locked until prerequisites complete") }
    return isCompleted
      ? String(localized: "Use the actions rotor to show details")
      : String(localized: "Use the actions rotor for Mark complete or Show details")
  }

  var checkboxLabel: String {
    isCompleted
      ? String(localized: "\(task.title), completed")
      : String(localized: "Mark \(task.title) complete")
  }

  var actions: [Action] {
    if task.isLocked { return [.explainLock] }
    var actions: [Action] = []
    if !isCompleted { actions.append(.markComplete) }
    if hasDetails { actions.append(isExpanded ? .hideDetails : .showDetails) }
    return actions
  }
}
