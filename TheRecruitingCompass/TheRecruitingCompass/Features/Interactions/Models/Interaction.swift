import Foundation
import SwiftUI

struct Interaction: Identifiable, Codable, Sendable {
  let id: String
  let type: InteractionType
  let direction: Direction
  let schoolId: String?
  let coachId: String?
  let subject: String?
  let content: String?
  let sentiment: Sentiment?
  let occurredAt: String?
  let loggedBy: String?
  let attachments: [String]?
  let familyUnitId: String
  let createdAt: String
  let updatedAt: String?

  var displayDate: Date {
    if let occurredAt {
      if let date = Self.iso8601Formatter.date(from: occurredAt) { return date }
      if let date = Self.iso8601FallbackFormatter.date(from: occurredAt) { return date }
    }
    if let date = Self.iso8601Formatter.date(from: createdAt) { return date }
    if let date = Self.iso8601FallbackFormatter.date(from: createdAt) { return date }
    return Date()
  }

  var hasAttachments: Bool {
    !(attachments ?? []).isEmpty
  }

  var attachmentCount: Int {
    (attachments ?? []).count
  }

  var displaySubject: String {
    subject ?? type.displayName
  }

  static let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  static let iso8601FallbackFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  enum CodingKeys: String, CodingKey {
    case id
    case type
    case direction
    case schoolId = "school_id"
    case coachId = "coach_id"
    case subject
    case content
    case sentiment
    case occurredAt = "occurred_at"
    case loggedBy = "logged_by"
    case attachments
    case familyUnitId = "family_unit_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

enum InteractionType: String, Codable, CaseIterable, Sendable {
  case email
  case phoneCall = "phone_call"
  case text
  case inPersonVisit = "in_person_visit"
  case virtualMeeting = "virtual_meeting"
  case camp
  case showcase
  case tweet
  case directMessage = "dm"
  case unknown

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = InteractionType(rawValue: rawValue) ?? .unknown
  }

  var displayName: String {
    switch self {
    case .email: return "Email"
    case .phoneCall: return "Phone Call"
    case .text: return "Text"
    case .inPersonVisit: return "In-Person Visit"
    case .virtualMeeting: return "Virtual Meeting"
    case .camp: return "Camp"
    case .showcase: return "Showcase"
    case .tweet: return "Tweet"
    case .directMessage: return "Direct Message"
    case .unknown: return "Unknown"
    }
  }

  var iconName: String {
    switch self {
    case .email: return "envelope.fill"
    case .phoneCall: return "phone.fill"
    case .text: return "bubble.left.fill"
    case .inPersonVisit: return "person.2.fill"
    case .virtualMeeting: return "video.fill"
    case .camp: return "figure.run"
    case .showcase: return "star.fill"
    case .tweet: return "bubble.left.fill"
    case .directMessage: return "paperplane.fill"
    case .unknown: return "questionmark.circle.fill"
    }
  }

  var iconColor: Color {
    switch self {
    case .email: return .blue
    case .phoneCall: return .purple
    case .text: return .green
    case .inPersonVisit: return .orange
    case .virtualMeeting: return .indigo
    case .camp: return .orange
    case .showcase: return .pink
    case .tweet: return .cyan
    case .directMessage: return .purple
    case .unknown: return .gray
    }
  }
}

enum Direction: String, Codable, CaseIterable, Sendable {
  case outbound
  case inbound

  var displayName: String {
    switch self {
    case .outbound: return "Outbound"
    case .inbound: return "Inbound"
    }
  }

  var subtitle: String {
    switch self {
    case .outbound: return "We initiated"
    case .inbound: return "They initiated"
    }
  }

  var badgeColor: Color {
    switch self {
    case .outbound: return .purple
    case .inbound: return .green
    }
  }
}

enum Sentiment: String, Codable, CaseIterable, Sendable {
  case veryPositive = "very_positive"
  case positive
  case neutral
  case negative

  var displayName: String {
    switch self {
    case .veryPositive: return "Very Positive"
    case .positive: return "Positive"
    case .neutral: return "Neutral"
    case .negative: return "Negative"
    }
  }

  var badgeColor: Color {
    switch self {
    case .veryPositive: return .green
    case .positive: return .blue
    case .neutral: return .gray
    case .negative: return .red
    }
  }

  var isPositive: Bool {
    self == .veryPositive || self == .positive
  }
}

enum TimePeriod: Int, CaseIterable, Sendable {
  case last7Days = 7
  case last14Days = 14
  case last30Days = 30
  case last90Days = 90

  var displayName: String {
    switch self {
    case .last7Days: return "Last 7 days"
    case .last14Days: return "Last 14 days"
    case .last30Days: return "Last 30 days"
    case .last90Days: return "Last 90 days"
    }
  }
}
