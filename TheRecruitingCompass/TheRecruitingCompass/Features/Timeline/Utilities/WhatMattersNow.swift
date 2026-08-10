import Foundation

/// Selects the single highest-priority "what matters now" task for a phase,
/// mirroring the web dashboard's `getWhatMattersNow` (utils/whatMattersNow.ts):
/// current-grade, incomplete, required tasks that carry a "why it matters"
/// note, ranked by category priority (+2 when the task has dependencies).
enum WhatMattersNow {
  private static let categoryPriority: [String: Int] = [
    "academic-standing": 10,
    "visibility-building": 8,
    "communication": 8,
    "evaluation": 7,
    "decision-making": 9,
    "documentation": 6,
    "training": 5
  ]

  /// Top-priority task for the phase, or nil when nothing pending. Ties resolve
  /// to the earliest task in the input order (matching the web's stable sort).
  static func topPriority(phase: TimelinePhase, tasks: [TaskWithStatus]) -> TaskWithStatus? {
    let grade = phase.gradeLevel
    let relevant = tasks.filter { task in
      task.gradeLevel == grade
        && task.effectiveStatus != .completed
        && task.required
        && !(task.whyItMatters ?? "").isEmpty
    }
    return relevant.enumerated().max { lhs, rhs in
      let lhsPriority = priority(lhs.element)
      let rhsPriority = priority(rhs.element)
      // Greatest = highest priority; on a tie prefer the lower input index.
      return lhsPriority != rhsPriority ? lhsPriority < rhsPriority : lhs.offset > rhs.offset
    }?.element
  }

  private static func priority(_ task: TaskWithStatus) -> Int {
    let base = categoryPriority[task.category] ?? 5
    let dependencyBonus = task.dependencyTaskIds.isEmpty ? 0 : 2
    return base + dependencyBonus
  }
}
