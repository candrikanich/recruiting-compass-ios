import Foundation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "MetricsExportService"
)

struct MetricsExportService {
  func prepareCSV(metrics: [PerformanceMetric], eventName: String) throws -> URL {
    var rows: [String] = ["Metric Type,Value,Unit,Recorded Date,Verified,Notes"]
    for m in metrics {
      let notesEscaped = (m.notes ?? "").replacing("\"", with: "\"\"")
      let notes = notesEscaped.isEmpty ? "" : "\"\(notesEscaped)\""
      let dateStr = DateFormatting.isoExportFormatter.string(from: m.recordedDate)
      rows.append("\(m.displayName),\(m.value),\(m.unit),\(dateStr),\(m.verified),\(notes)")
    }
    let csv = rows.joined(separator: "\n")
    let safeName = eventName
      .filter { $0.isLetter || $0.isNumber || $0 == " " }
      .replacing(" ", with: "-")
    let fileName = "event-metrics-\(safeName).csv"
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    try csv.write(to: fileURL, atomically: true, encoding: .utf8)
    logger.info("CSV export prepared: \(fileName)")
    return fileURL
  }

  func cleanup(url: URL) {
    try? FileManager.default.removeItem(at: url)
  }
}
