import Foundation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "CoachExportService"
)

struct CoachExportService {
  func prepareCSV(coaches: [Coach], schoolName: (String) -> String) throws -> URL {
    var rows: [String] = [
      "First Name,Last Name,Role,School,Email,Phone,Twitter,Instagram,Last Contact Date,Notes"
    ]
    for coach in coaches {
      let fields: [String] = [
        coach.firstName,
        coach.lastName,
        coach.role.displayName,
        schoolName(coach.schoolId),
        coach.email ?? "",
        coach.phone ?? "",
        coach.twitterHandle ?? "",
        coach.instagramHandle ?? "",
        Self.lastContactCalendarDate(coach.lastContactDate),
        coach.notes ?? ""
      ]
      rows.append(fields.map(escaped).joined(separator: ","))
    }

    let csv = rows.joined(separator: "\n") + "\n"
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("coaches-export-\(UUID().uuidString).csv")
    try csv.write(to: fileURL, atomically: true, encoding: .utf8)
    logger.info("CSV export prepared: \(coaches.count) coaches")
    return fileURL
  }

  private static let lastContactDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
  }()

  /// Web treats the leading `YYYY-MM-DD` of the stored timestamp as the
  /// calendar date, with no timezone conversion — match that exactly rather
  /// than parsing the full instant and reformatting in device-local time,
  /// which can shift the date near a local-midnight boundary. Building the
  /// `Date` from parsed Y/M/D components (not a timezone-aware ISO parse)
  /// keeps the calendar day stable regardless of device timezone.
  private static func lastContactCalendarDate(_ isoString: String?) -> String {
    guard let isoString, isoString.count >= 10 else { return "" }
    let datePart = isoString.prefix(10).split(separator: "-")
    guard datePart.count == 3,
          let year = Int(datePart[0]), let month = Int(datePart[1]), let day = Int(datePart[2]) else {
      return ""
    }
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    guard let date = Calendar.current.date(from: components) else { return "" }
    return lastContactDateFormatter.string(from: date)
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
