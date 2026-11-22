import Foundation

/// Next steps for an athlete who has not joined, picked from the task catalog by the grade the parent staged.
/// Mirrors web `pendingAthleteSteps` (`utils/firstRun.ts`) and `getWhatMattersNow`: completion state is dropped on
/// purpose, because nothing belongs to the athlete yet and nothing may read as done.
enum PendingAthleteSteps {
  static let maxSteps = 3

  /// Nil until the parent staged a graduation year: never a default grade.
  static func grade(graduationYear: Int?, referenceDate: Date = .now) -> Int? {
    graduationYear.map { GradeLevelHelper.calculateCurrentGrade(graduationYear: $0, referenceDate: referenceDate) }
  }

  /// Required tasks for the grade that explain why they matter, highest priority first, ties broken by task id so
  /// web and iOS surface the same steps.
  static func steps(from catalog: [TaskRow], grade: Int) -> [WhatMattersItem] {
    catalog
      .filter { $0.gradeLevel == grade && $0.required && !($0.whyItMatters ?? "").isEmpty }
      .map { row in
        WhatMattersItem(
          taskId: row.id,
          title: row.title,
          whyItMatters: row.whyItMatters ?? "",
          category: row.category,
          priority: categoryPriority(row.category) + ((row.dependencyTaskIds ?? []).isEmpty ? 0 : 2),
          isRequired: true
        )
      }
      .sorted { $0.priority != $1.priority ? $0.priority > $1.priority : $0.taskId < $1.taskId }
      .prefix(maxSteps)
      .map { $0 }
  }

  /// Web `CATEGORY_PRIORITY`: higher is more urgent, unknown categories sit at 5.
  private static func categoryPriority(_ category: String) -> Int {
    switch category {
    case "academic": return 10
    case "recruiting": return 9
    case "athletic": return 8
    case "exposure": return 7
    default: return 5
    }
  }
}
