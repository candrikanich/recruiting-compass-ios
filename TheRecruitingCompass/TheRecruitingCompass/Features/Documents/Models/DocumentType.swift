import Foundation

enum DocumentType: String, Codable, CaseIterable, Sendable {
  case highlightVideo = "highlight_video"
  case transcript = "transcript"
  case resume = "resume"
  case recLetter = "rec_letter"
  case questionnaire = "questionnaire"
  case statsSheet = "stats_sheet"
  case coachAttachment = "coach_attachment"
  case other = "other"

  /// Types a user can select when uploading a document.
  /// Excludes server-only types like `.coachAttachment` and the `.other` fallback.
  static let uploadableCases: [DocumentType] = allCases.filter { type in
    switch type {
    case .coachAttachment, .other: return false
    default: return true
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = DocumentType(rawValue: rawValue) ?? .other
  }

  var label: String {
    switch self {
    case .highlightVideo: return String(localized: "Highlight Video")
    case .transcript: return String(localized: "Transcript")
    case .resume: return String(localized: "Resume")
    case .recLetter: return String(localized: "Recommendation Letter")
    case .questionnaire: return String(localized: "Questionnaire")
    case .statsSheet: return String(localized: "Stats Sheet")
    case .coachAttachment: return String(localized: "Coach Attachment")
    case .other: return String(localized: "Document")
    }
  }

  var typeEmoji: String {
    switch self {
    case .highlightVideo: return "🎥"
    case .transcript: return "📄"
    case .resume: return "📋"
    case .recLetter: return "💌"
    case .questionnaire: return "📝"
    case .statsSheet: return "📊"
    case .coachAttachment: return "📎"
    case .other: return "📁"
    }
  }

  var allowedExtensions: [String] {
    switch self {
    case .highlightVideo: return [".mp4", ".mov", ".avi"]
    case .transcript: return [".pdf", ".txt"]
    case .resume: return [".pdf", ".doc", ".docx"]
    case .recLetter: return [".pdf"]
    case .questionnaire: return [".pdf", ".doc", ".docx"]
    case .statsSheet: return [".csv", ".xls", ".xlsx"]
    case .coachAttachment: return [".pdf", ".doc", ".docx", ".jpg", ".png", ".txt"]
    case .other: return [".pdf", ".doc", ".docx", ".txt"]
    }
  }
}
