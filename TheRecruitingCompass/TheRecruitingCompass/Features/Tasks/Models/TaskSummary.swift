import Foundation

struct TaskSummary: Codable, Identifiable, Sendable {
  let id: String
  let title: String
}
