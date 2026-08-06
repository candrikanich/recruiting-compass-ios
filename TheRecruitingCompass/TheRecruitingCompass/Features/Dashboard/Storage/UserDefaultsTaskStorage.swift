import Foundation

final class UserDefaultsTaskStorage: QuickTaskStorage {
  nonisolated(unsafe) private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  func saveTasks(_ tasks: [QuickTask], forUserId userId: String) throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(tasks)
    userDefaults.set(data, forKey: "user_tasks-\(userId)")
  }

  func loadTasks(forUserId userId: String) throws -> [QuickTask] {
    guard let data = userDefaults.data(forKey: "user_tasks-\(userId)") else {
      return []
    }
    let decoder = JSONDecoder()
    return try decoder.decode([QuickTask].self, from: data)
  }

  func deleteTasks(forUserId userId: String) throws {
    userDefaults.removeObject(forKey: "user_tasks-\(userId)")
  }
}
