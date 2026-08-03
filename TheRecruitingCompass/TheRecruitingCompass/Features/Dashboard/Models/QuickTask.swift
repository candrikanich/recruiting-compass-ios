import Foundation

struct QuickTask: Codable, Identifiable, Sendable {
  let id: String
  var text: String
  var isCompleted: Bool
  let createdAt: Date

  init(
    id: String = UUID().uuidString,
    text: String,
    isCompleted: Bool = false,
    createdAt: Date = .now
  ) {
    self.id = id
    self.text = text
    self.isCompleted = isCompleted
    self.createdAt = createdAt
  }
}
