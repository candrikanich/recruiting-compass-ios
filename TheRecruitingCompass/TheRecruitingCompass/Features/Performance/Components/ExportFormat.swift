import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
  case csv = "CSV"
  case pdf = "PDF"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .csv: return "doc.text"
    case .pdf: return "doc.richtext"
    }
  }

  var description: String {
    switch self {
    case .csv: return "Spreadsheet format, compatible with Excel"
    case .pdf: return "Formatted document with charts and tables"
    }
  }
}
