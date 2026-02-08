import Foundation

struct InteractionTrend: Codable, Identifiable, Sendable {
  let id: String
  let date: String
  let count: Int

  var dateFormatted: Date {
    ISO8601DateFormatter().date(from: date) ?? Date()
  }
}
