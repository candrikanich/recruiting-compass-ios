import Foundation

struct Document: Codable, Identifiable, Sendable {
  let id: String
  let userId: String?
  let type: DocumentType
  let title: String
  let description: String?
  let fileUrl: String
  let fileType: String?
  let version: Int
  let schoolId: String?
  let isCurrent: Bool
  let sharedWithSchools: [String]
  let uploadedBy: String?
  let createdAt: String?
  let updatedAt: String?

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case type
    case title
    case description
    case fileUrl = "file_url"
    case fileType = "file_type"
    case version
    case schoolId = "school_id"
    case isCurrent = "is_current"
    case sharedWithSchools = "shared_with_schools"
    case uploadedBy = "uploaded_by"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

  var isShared: Bool {
    !sharedWithSchools.isEmpty
  }

  var typeEmoji: String {
    type.typeEmoji
  }

  var displayDate: String {
    guard let created = createdAt else { return "Unknown" }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: created) {
      return date.formatted(date: .abbreviated, time: .omitted)
    }
    let basicFormatter = ISO8601DateFormatter()
    basicFormatter.formatOptions = [.withInternetDateTime]
    if let date = basicFormatter.date(from: created) {
      return date.formatted(date: .abbreviated, time: .omitted)
    }
    return "Unknown"
  }

  var typeLabel: String {
    type.label
  }

  var isVideo: Bool {
    type == .highlightVideo || (fileType?.lowercased().contains("video") == true)
  }

  var isImage: Bool {
    fileType?.lowercased().contains("image") == true
  }

  var isPDF: Bool {
    fileType?.lowercased() == "application/pdf"
  }

  var canPreview: Bool {
    isVideo || isImage || isPDF
  }
}
