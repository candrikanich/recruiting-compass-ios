import Foundation
@testable import TheRecruitingCompass

final class MockQuickTaskStorage: QuickTaskStorage, @unchecked Sendable {
  // MARK: - Call Counts

  var saveTasksCallCount = 0
  var loadTasksCallCount = 0
  var deleteTasksCallCount = 0

  // MARK: - Error Flags

  var shouldThrowOnSave = false
  var shouldThrowOnLoad = false
  var shouldThrowOnDelete = false

  // MARK: - In-Memory Storage

  var storedTasks: [String: [QuickTask]] = [:]

  // MARK: - QuickTaskStorage

  func saveTasks(_ tasks: [QuickTask], forUserId userId: String) throws {
    saveTasksCallCount += 1
    if shouldThrowOnSave {
      throw NSError(domain: "MockTaskStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
    }
    storedTasks[userId] = tasks
  }

  func loadTasks(forUserId userId: String) throws -> [QuickTask] {
    loadTasksCallCount += 1
    if shouldThrowOnLoad {
      throw NSError(domain: "MockTaskStorage", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock load error"])
    }
    return storedTasks[userId] ?? []
  }

  func deleteTasks(forUserId userId: String) throws {
    deleteTasksCallCount += 1
    if shouldThrowOnDelete {
      throw NSError(domain: "MockTaskStorage", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mock delete error"])
    }
    storedTasks.removeValue(forKey: userId)
  }
}
