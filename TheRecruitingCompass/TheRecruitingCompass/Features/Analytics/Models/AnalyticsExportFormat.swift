import Foundation

enum AnalyticsExportFormat: String, CaseIterable, Identifiable, Sendable {
  case csv
  case excel
  case pdf

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .csv: return "CSV"
    case .excel: return "Excel"
    case .pdf: return "PDF"
    }
  }

  var fileExtension: String {
    switch self {
    case .csv: return "csv"
    case .excel: return "xlsx"
    case .pdf: return "pdf"
    }
  }

  var mimeType: String {
    switch self {
    case .csv: return "text/csv"
    case .excel: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    case .pdf: return "application/pdf"
    }
  }

  var iconName: String {
    switch self {
    case .csv: return "tablecells"
    case .excel: return "tablecells.fill"
    case .pdf: return "doc.richtext"
    }
  }
}
