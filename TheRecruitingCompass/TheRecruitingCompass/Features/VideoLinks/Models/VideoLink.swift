import Foundation

enum VideoLinkPlatform: String, Codable, Sendable, CaseIterable {
  case hudl, youtube, vimeo, unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = VideoLinkPlatform(rawValue: raw) ?? .unknown
  }

  var displayName: String {
    switch self {
    case .hudl: return String(localized: "Hudl")
    case .youtube: return String(localized: "YouTube")
    case .vimeo: return String(localized: "Vimeo")
    case .unknown: return String(localized: "Other")
    }
  }

  /// Platforms a user may pick when creating a link (excludes `.unknown`).
  static var selectable: [VideoLinkPlatform] { [.hudl, .youtube, .vimeo] }
}

enum VideoLinkHealth: String, Codable, Sendable {
  case healthy, broken, unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = VideoLinkHealth(rawValue: raw) ?? .unknown
  }

  var displayName: String {
    switch self {
    case .healthy: return String(localized: "Working")
    case .broken: return String(localized: "Broken link")
    case .unknown: return String(localized: "Not checked")
    }
  }
}

struct VideoLink: Codable, Identifiable, Sendable, Equatable {
  let id: String
  let userId: String
  let familyUnitId: String?
  let platform: VideoLinkPlatform
  let url: String
  let title: String?
  let position: Int
  let healthStatus: VideoLinkHealth
  let lastHealthCheck: Date?
  let createdAt: Date?
  let updatedAt: Date?

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
    case platform, url, title, position
    case healthStatus = "health_status"
    case lastHealthCheck = "last_health_check"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}
