import Foundation

struct DocumentVersion: Identifiable, Sendable {
  let id: String
  let version: Int
  let fileUrl: String
  let isCurrent: Bool
  let createdAt: String

  private static let fractionalSecondsFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let basicFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  var displayDate: String {
    if let date = Self.fractionalSecondsFormatter.date(from: createdAt) {
      return date.formatted(date: .abbreviated, time: .shortened)
    }
    if let date = Self.basicFormatter.date(from: createdAt) {
      return date.formatted(date: .abbreviated, time: .shortened)
    }
    return "Unknown"
  }
}
