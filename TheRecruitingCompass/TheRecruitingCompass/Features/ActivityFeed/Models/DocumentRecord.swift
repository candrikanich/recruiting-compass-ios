import Foundation

struct DocumentRecord: Identifiable, Codable, Sendable {
  let id: String
  let title: String
  let type: String?
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id, title, type
    case createdAt = "created_at"
  }
}
