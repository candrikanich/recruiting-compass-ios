import Foundation

struct InteractionTrend: Codable, Identifiable, Sendable {
  let id: String
  let date: String
  let count: Int

  private static let fractionalFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static let basicFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  var dateFormatted: Date {
    Self.fractionalFormatter.date(from: date) ?? Self.basicFormatter.date(from: date) ?? Date()
  }
}
