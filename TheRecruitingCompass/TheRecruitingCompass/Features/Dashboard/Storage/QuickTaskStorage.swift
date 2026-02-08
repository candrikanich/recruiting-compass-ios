import Foundation

protocol QuickTaskStorage: Sendable {
  func saveTasks(_ tasks: [QuickTask], forUserId userId: String) throws
  func loadTasks(forUserId userId: String) throws -> [QuickTask]
  func deleteTasks(forUserId userId: String) throws
}
