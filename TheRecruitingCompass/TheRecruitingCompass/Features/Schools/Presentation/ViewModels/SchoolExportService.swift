import Foundation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "SchoolExportService"
)

struct SchoolExportService {
  func prepareCSV(schools: [School]) throws -> URL {
    var rows: [String] = [
      "School Name,Division,Conference,Location,Status,Pros,Cons"
    ]
    for school in schools {
      let status = SchoolStatus(rawValue: school.status)?.displayName ?? school.status
      let fields: [String] = [
        school.name,
        school.division ?? "",
        school.conference ?? "",
        school.location ?? "",
        status,
        school.pros.joined(separator: "; "),
        school.cons.joined(separator: "; ")
      ]
      rows.append(fields.map(escaped).joined(separator: ","))
    }

    let csv = rows.joined(separator: "\n") + "\n"
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("schools-export-\(UUID().uuidString).csv")
    try csv.write(to: fileURL, atomically: true, encoding: .utf8)
    logger.info("CSV export prepared: \(schools.count) schools")
    return fileURL
  }

  func cleanup(url: URL) {
    try? FileManager.default.removeItem(at: url)
  }

  /// Formula-injection guard (OWASP CSV Injection mitigation): a cell opened
  /// by Excel/Numbers/Sheets that starts with =, +, -, @, tab, or CR can
  /// execute as a formula. Prefixing with a single quote forces text
  /// interpretation without altering the visible value in any spreadsheet app.
  private static let formulaTriggerChars: Set<Character> = ["=", "+", "-", "@", "\t", "\r"]

  private func escaped(_ field: String) -> String {
    var value = field
    if let first = value.first, Self.formulaTriggerChars.contains(first) {
      value = "'" + value
    }
    guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
      return value
    }
    return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
  }
}
