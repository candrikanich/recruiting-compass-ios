import Foundation

struct DocumentRecord: Identifiable, Codable, Sendable {
  let id: String
  let title: String
  let type: String?
  let createdAt: String
  /// Who uploaded it (`uploaded_by`). `user_id` is the document's owner, which for an inbound-draft confirm is the
  /// athlete rather than the parent who uploaded; nil once the uploader's account is gone.
  var uploadedBy: String?

  enum CodingKeys: String, CodingKey {
    case id, title, type
    case uploadedBy = "uploaded_by"
    case createdAt = "created_at"
  }
}
