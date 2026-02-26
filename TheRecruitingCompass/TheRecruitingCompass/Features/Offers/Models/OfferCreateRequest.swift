import Foundation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "OfferCreateRequest"
)

struct OfferCreateRequest: Codable, Sendable {
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

  enum CodingKeys: String, CodingKey {
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
  }

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  init(userId: String, form: NewOfferFormState) {
    self.userId = userId
    let resolvedSchoolId = form.schoolId ?? ""
    if resolvedSchoolId.isEmpty {
      logger.warning("OfferCreateRequest initialized with empty schoolId — form.schoolId was nil")
    }
    self.schoolId = resolvedSchoolId
    self.offerType = form.offerType
    self.scholarshipAmount = Double(form.scholarshipAmount)
    self.scholarshipPercentage = form.scholarshipPercentage > 0 ? form.scholarshipPercentage : nil
    self.offerDate = Self.dateFormatter.string(from: form.offerDate)
    self.deadlineDate = form.hasDeadline ? Self.dateFormatter.string(from: form.deadlineDate) : nil
    self.status = form.status
    self.conditions = nil
    self.notes = form.notes.isEmpty ? nil : form.notes
  }
}
