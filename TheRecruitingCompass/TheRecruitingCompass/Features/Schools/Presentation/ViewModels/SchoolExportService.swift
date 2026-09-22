import Foundation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "SchoolExportService"
)

struct SchoolExportService {
  private static let deadlineFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
  }()

  /// `deadline_date` is a date-only DB column (`YYYY-MM-DD`). `Offer.displayDeadlineDate`
  /// parses it at UTC midnight, which renders a day early in negative-UTC-offset timezones
  /// (every US timezone) — parse the calendar components directly at LOCAL midnight instead,
  /// matching web's `parseLocalDateOnly`.
  private static let deadlineDateOnlyParser: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    return formatter
  }()

  private func formattedDeadline(_ offer: Offer?) -> String {
    guard let dateOnly = offer?.deadlineDate?.prefix(10),
          let date = Self.deadlineDateOnlyParser.date(from: String(dateOnly)) else { return "" }
    return Self.deadlineFormatter.string(from: date)
  }

  func prepareCSV(
    schools: [School],
    coaches: [Coach] = [],
    offers: [Offer] = [],
    interactions: [Interaction] = []
  ) throws -> URL {
    let coachCounts = Dictionary(grouping: coaches, by: \.schoolId).mapValues(\.count)
    let interactionCounts = Dictionary(grouping: interactions, by: { $0.schoolId ?? "" }).mapValues(\.count)
    let offersBySchool = Dictionary(grouping: offers, by: \.schoolId).compactMapValues(\.first)

    var rows: [String] = [
      "School Name,Division,Conference,Location,Status,Coaches,Interactions,Offer Type,Scholarship %,Offer Status,Deadline,Pros,Cons"
    ]
    for school in schools {
      let status = SchoolStatus(rawValue: school.status)?.displayName ?? school.status
      let offer = offersBySchool[school.id]
      let fields: [String] = [
        school.name,
        school.division ?? "",
        school.conference ?? "",
        school.location ?? "",
        status,
        String(coachCounts[school.id] ?? 0),
        String(interactionCounts[school.id] ?? 0),
        offer?.offerType.displayName ?? "",
        offer?.scholarshipPercentage.map { "\($0)%" } ?? "",
        offer?.status.displayName ?? "",
        formattedDeadline(offer),
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
