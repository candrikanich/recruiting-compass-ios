import Foundation

struct OfferEditData: Sendable {
  var offerType: OfferType
  var status: OfferStatus
  var scholarshipAmount: Double?
  var scholarshipPercentage: Int?
  var offerDate: Date
  var deadlineDate: Date?
  var conditions: String
  var notes: String

  init() {
    self.offerType = .scholarship
    self.status = .pending
    self.scholarshipAmount = nil
    self.scholarshipPercentage = nil
    self.offerDate = .now
    self.deadlineDate = nil
    self.conditions = ""
    self.notes = ""
  }

  init(from offer: Offer) {
    self.offerType = offer.offerType
    self.status = offer.status
    self.scholarshipAmount = offer.scholarshipAmount
    self.scholarshipPercentage = offer.scholarshipPercentage
    self.offerDate = offer.displayOfferDate
    self.deadlineDate = offer.displayDeadlineDate
    self.conditions = offer.conditions ?? ""
    self.notes = offer.notes ?? ""
  }
}

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
