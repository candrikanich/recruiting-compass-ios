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

  /// Display name, distinct from `rawValue` (which is used for `Identifiable` id).
  var displayName: String {
    switch self {
    case .csv: return String(localized: "CSV")
    case .pdf: return String(localized: "PDF")
    }
  }

  var description: String {
    switch self {
    case .csv: return String(localized: "Spreadsheet format, compatible with Excel")
    case .pdf: return String(localized: "Formatted document with charts and tables")
    }
  }

  func filename(on date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return "performance_metrics_\(dateFormatter.string(from: date)).\(rawValue.lowercased())"
  }
}
