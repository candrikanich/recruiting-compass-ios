import Foundation

struct DocumentVersion: Identifiable, Sendable {
  let id: String
  let version: Int
  let fileUrl: String
  let isCurrent: Bool
  let createdAt: String

  var displayDate: String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: createdAt) {
      return date.formatted(date: .abbreviated, time: .shortened)
    }
    let basicFormatter = ISO8601DateFormatter()
    basicFormatter.formatOptions = [.withInternetDateTime]
    if let date = basicFormatter.date(from: createdAt) {
      return date.formatted(date: .abbreviated, time: .shortened)
    }
    return "Unknown"
  }
}
