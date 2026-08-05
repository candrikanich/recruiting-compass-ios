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
