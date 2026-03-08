import Foundation

struct TaskSummary: @preconcurrency Codable, Identifiable, Sendable {
  let id: String
  let title: String
}
