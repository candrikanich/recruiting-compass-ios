import Foundation

enum DocumentType: String, Codable, CaseIterable, Sendable {
  case highlightVideo = "highlight_video"
  case transcript = "transcript"
  case resume = "resume"
  case recLetter = "rec_letter"
  case questionnaire = "questionnaire"
  case statsSheet = "stats_sheet"

  var label: String {
    switch self {
    case .highlightVideo: return "Highlight Video"
    case .transcript: return "Transcript"
    case .resume: return "Resume"
    case .recLetter: return "Recommendation Letter"
    case .questionnaire: return "Questionnaire"
    case .statsSheet: return "Stats Sheet"
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
    }
  }
}
