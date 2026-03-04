import Foundation

struct Offer: Codable, Identifiable, Sendable {
  let id: String
  let userId: String
  let schoolId: String
  let offerType: OfferType
  let scholarshipAmount: Double?
  let scholarshipPercentage: Int?
  let offerDate: String
  let deadlineDate: String?
  let status: OfferStatus
  let conditions: String?
  let notes: String?
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case schoolId = "school_id"
    case offerType = "offer_type"
    case scholarshipAmount = "scholarship_amount"
    case scholarshipPercentage = "scholarship_percentage"
    case offerDate = "offer_date"
    case deadlineDate = "deadline_date"
    case status
    case conditions
    case notes
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

  // MARK: - Date Parsing

  var displayOfferDate: Date {
    Self.parseDate(offerDate) ?? Date()
  }

  var displayDeadlineDate: Date? {
    guard let deadlineDate else { return nil }
    return Self.parseDate(deadlineDate)
  }

  // MARK: - Deadline Computed Properties

  var daysUntilDeadline: Int? {
    guard let deadline = displayDeadlineDate else { return nil }
    var utcCal = Calendar(identifier: .gregorian)
    utcCal.timeZone = TimeZone(identifier: "UTC") ?? .current
    let startToday = utcCal.startOfDay(for: Date())
    let startDeadline = utcCal.startOfDay(for: deadline)
    return utcCal.dateComponents([.day], from: startToday, to: startDeadline).day
  }

  var deadlineUrgency: DeadlineUrgency {
    guard let days = daysUntilDeadline else { return .none }
    if days < 0 { return .overdue }
    if days <= 7 { return .critical }
    if days <= 30 { return .urgent }
    return .normal
  }

  // MARK: - Display Helpers

  var formattedAmount: String? {
    guard let amount = scholarshipAmount, amount > 0 else { return nil }
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount))
  }

  var formattedPercentage: String? {
    guard let pct = scholarshipPercentage, pct > 0 else { return nil }
    return "\(pct)%"
  }

  // MARK: - Private

  private static let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let iso8601BasicFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  private static let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter
  }()

  static func parseDate(_ string: String) -> Date? {
    iso8601Formatter.date(from: string)
      ?? iso8601BasicFormatter.date(from: string)
      ?? dateOnlyFormatter.date(from: string)
  }
}
