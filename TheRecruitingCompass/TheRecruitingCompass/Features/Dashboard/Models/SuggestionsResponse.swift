import Foundation

/// Response from GET /api/suggestions?location=dashboard
struct SuggestionsResponse: Codable, Sendable {
  let suggestions: [Suggestion]
  /// Optional: API may omit when no pending count is provided.
  let pendingCount: Int

  enum CodingKeys: String, CodingKey {
    case suggestions
    case pendingCount = "pending_count"
  }

  init(suggestions: [Suggestion], pendingCount: Int = 0) {
    self.suggestions = suggestions
    self.pendingCount = pendingCount
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    suggestions = try c.decode([Suggestion].self, forKey: .suggestions)
    pendingCount = try c.decodeIfPresent(Int.self, forKey: .pendingCount) ?? 0
  }
}
