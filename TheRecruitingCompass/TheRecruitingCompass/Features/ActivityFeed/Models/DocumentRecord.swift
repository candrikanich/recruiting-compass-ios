import Foundation

struct DocumentRecord: Identifiable, Codable, Sendable {
  let id: String
  let title: String
  let type: String?
  let createdAt: String
  /// Uploader; nil for rows from before the column was selected.
  var userId: String?

  enum CodingKeys: String, CodingKey {
    case id, title, type
    case userId = "user_id"
    case createdAt = "created_at"
  }
}
