import Foundation

enum ActivityEventType: String, CaseIterable, Sendable, Codable {
  case interaction
  case schoolStatusChange = "school_status_change"
  case documentUpload = "document_upload"

  var label: String {
    switch self {
    case .interaction: return "Interactions"
    case .schoolStatusChange: return "School Status Changes"
    case .documentUpload: return "Documents"
    }
  }
}
