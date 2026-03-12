import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "TasksListViewModel")

private enum FilterStorage {
  static func statusKey(athleteId: String) -> String { "taskStatusFilter_\(athleteId)" }
  static func urgencyKey(athleteId: String) -> String { "taskUrgencyFilter_\(athleteId)" }
}

@Observable
@MainActor
final class TasksListViewModel {
  var tasks: [TaskWithStatus] = []
  var isLoading = false
  var errorMessage: String?
  var currentGradeLevel: Int = 10
  var statusFilter: TaskStatusFilter = .all {
    didSet { persistFilters() }
  }
  var urgencyFilter: TaskUrgencyFilter = .all {
    didSet { persistFilters() }
  }
  var expandedTaskId: String?
  var showSuccessMessage = false
  var isViewingAsParent: Bool { familyManager.isParentViewingAthlete }
  var currentAthleteId: String? {
    if let athlete = familyManager.selectedAthlete { return athlete.userId }
    return authManager.user?.id
  }

  private let tasksService: any TasksManaging
  private let authManager: any AuthManaging
  private let familyManager: FamilyManager

  /// When set, used to compute currentGradeLevel; otherwise a default grade is used.
  var graduationYear: Int?

  // MARK: - Computed

  var filteredTasks: [TaskWithStatus] {
    var result = tasks
    result = result.filter { statusFilter.matches($0.effectiveStatus) }
    result = result.filter { urgencyFilter.matches($0.deadlineUrgency) }
    return result.sorted { lhs, rhs in
      if lhs.required != rhs.required { return lhs.required }
      let uOrder: (TaskDeadlineUrgency) -> Int = { u in
        switch u {
        case .critical: return 0
        case .urgent: return 1
        case .upcoming: return 2
        case .future: return 3
        case .none: return 4
        }
      }
      let lu = uOrder(lhs.deadlineUrgency), ru = uOrder(rhs.deadlineUrgency)
      if lu != ru { return lu < ru }
      return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
  }

  var progressCompleted: Int {
    tasks.filter { $0.effectiveStatus == .completed }.count
  }

  var progressTotal: Int {
    tasks.count
  }

  var progressPercentage: Int {
    guard progressTotal > 0 else { return 0 }
    return Int(round(Double(progressCompleted) / Double(progressTotal) * 100))
  }

  // MARK: - Init

  init(
    tasksService: (any TasksManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    familyManager: FamilyManager? = nil
  ) {
    self.tasksService = tasksService ?? TasksServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.familyManager = familyManager ?? .shared
  }

  private func persistFilters() {
    guard let id = currentAthleteId else { return }
    UserDefaults.standard.set(statusFilter.rawValue, forKey: FilterStorage.statusKey(athleteId: id))
    UserDefaults.standard.set(urgencyFilter.rawValue, forKey: FilterStorage.urgencyKey(athleteId: id))
  }

  func loadTasks() async {
    guard let athleteId = currentAthleteId else {
      errorMessage = "Unable to load tasks."
      return
    }

    if let year = graduationYear {
      currentGradeLevel = GradeLevelHelper.calculateCurrentGrade(graduationYear: year)
    } else {
      let defaultGradYear = Calendar.current.component(.year, from: Date()) + 2
      currentGradeLevel = GradeLevelHelper.calculateCurrentGrade(graduationYear: defaultGradYear)
    }

    statusFilter = (UserDefaults.standard.string(forKey: FilterStorage.statusKey(athleteId: athleteId)))
      .flatMap { TaskStatusFilter(rawValue: $0) } ?? .all
    urgencyFilter = (UserDefaults.standard.string(forKey: FilterStorage.urgencyKey(athleteId: athleteId)))
      .flatMap { TaskUrgencyFilter(rawValue: $0) } ?? .all

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      tasks = try await tasksService.fetchTasksWithStatus(gradeLevel: currentGradeLevel, athleteId: athleteId)
      logger.info("Loaded \(self.tasks.count) tasks for grade \(self.currentGradeLevel)")
    } catch {
      logger.error("Failed to load tasks: \(error.localizedDescription)")
      errorMessage = "Failed to load tasks. Please try again."
    }
  }

  func refresh() async {
    await loadTasks()
  }

  func setStatusFilter(_ filter: TaskStatusFilter) {
    statusFilter = filter
  }

  func setUrgencyFilter(_ filter: TaskUrgencyFilter) {
    urgencyFilter = filter
  }

  func toggleExpanded(taskId: String) {
    if expandedTaskId == taskId {
      expandedTaskId = nil
    } else {
      expandedTaskId = taskId
    }
  }

  func markComplete(taskId: String) async {
    guard !isViewingAsParent else { return }
    guard let userId = authManager.user?.id else { return }

    guard let task = tasks.first(where: { $0.id == taskId }) else { return }
    if task.isLocked {
      return
    }

    do {
      _ = try await tasksService.updateTaskStatus(taskId: taskId, status: .completed, userId: userId)
      showSuccessMessage = true
      await refresh()
    } catch {
      logger.error("Failed to mark task complete: \(error.localizedDescription)")
      errorMessage = "Failed to update task. Please try again."
    }
  }

  func clearSuccessMessage() {
    showSuccessMessage = false
  }


}
