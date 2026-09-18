import Foundation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "CoachExportService"
)

struct CoachExportService {
  private static let lastContactDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
  }()

  func prepareCSV(coaches: [Coach], schoolName: (String) -> String) throws -> URL {
    var rows: [String] = [
      "First Name,Last Name,Role,School,Email,Phone,Twitter,Instagram,Last Contact Date,Notes"
    ]
    for coach in coaches {
      var lastContactDate = ""
      if let date = coach.lastContactDateParsed {
        lastContactDate = Self.lastContactDateFormatter.string(from: date)
      }
      let fields: [String] = [
        coach.firstName,
        coach.lastName,
        coach.role.displayName,
        schoolName(coach.schoolId),
        coach.email ?? "",
        coach.phone ?? "",
        coach.twitterHandle ?? "",
        coach.instagramHandle ?? "",
        lastContactDate,
        coach.notes ?? ""
      ]
      rows.append(fields.map(escaped).joined(separator: ","))
    }

    let csv = rows.joined(separator: "\n") + "\n"
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("coaches-export.csv")
    try csv.write(to: fileURL, atomically: true, encoding: .utf8)
    logger.info("CSV export prepared: \(coaches.count) coaches")
    return fileURL
  }

  func cleanup(url: URL) {
    try? FileManager.default.removeItem(at: url)
  }

  /// Formula-injection guard: a cell opened by Excel/Numbers/Sheets that
  /// starts with =, +, -, or @ can execute as a formula. Prefixing with a
  /// single quote forces text interpretation without altering the visible
  /// value in any spreadsheet app.
  private static let formulaTriggerChars: Set<Character> = ["=", "+", "-", "@"]

  private func escaped(_ field: String) -> String {
    var value = field
    if let first = value.first, Self.formulaTriggerChars.contains(first) {
      value = "'" + value
    }
    guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
      return value
    }
    return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
  }
}
