import Foundation

struct OfferUpdateRequest: Codable, Sendable {
  let offerType: OfferType
  let status: OfferStatus
  let scholarshipAmount: Double?
  let scholarshipPercentage: Int?
  let offerDate: String
  let deadlineDate: String?
  let conditions: String?
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case offerType = "offer_type"
    case status
    case scholarshipAmount = "scholarship_amount"
    case scholarshipPercentage = "scholarship_percentage"
    case offerDate = "offer_date"
    case deadlineDate = "deadline_date"
    case conditions
    case notes
  }

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  init(from editData: OfferEditData) {
    self.offerType = editData.offerType
    self.status = editData.status
    self.scholarshipAmount = editData.scholarshipAmount
    self.scholarshipPercentage = editData.scholarshipPercentage
    self.offerDate = Self.dateFormatter.string(from: editData.offerDate)
    self.deadlineDate = editData.deadlineDate.map { Self.dateFormatter.string(from: $0) }
    self.conditions = editData.conditions.isEmpty ? nil : editData.conditions
    self.notes = editData.notes.isEmpty ? nil : editData.notes
  }
}
