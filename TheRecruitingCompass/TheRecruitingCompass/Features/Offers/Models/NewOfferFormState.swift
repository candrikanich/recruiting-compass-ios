import Foundation

struct NewOfferFormState: Sendable {
  var schoolId: String?
  var offerType: OfferType = .scholarship
  var status: OfferStatus = .pending
  var scholarshipPercentage: Int = 0
  var scholarshipAmount: String = ""
  var offerDate: Date = Date()
  var hasDeadline: Bool = false
  var deadlineDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
  var notes: String = ""

  var validationErrors: [String] {
    var errors: [String] = []
    if schoolId == nil {
      errors.append("Please select a school")
    }
    if scholarshipPercentage < 0 || scholarshipPercentage > 100 {
      errors.append("Scholarship percentage must be 0-100")
    }
    if !scholarshipAmount.isEmpty, Double(scholarshipAmount) == nil {
      errors.append("Scholarship amount must be a valid number")
    }
    return errors
  }

  var isValid: Bool {
    validationErrors.isEmpty
  }

  mutating func reset() {
    schoolId = nil
    offerType = .scholarship
    status = .pending
    scholarshipPercentage = 0
    scholarshipAmount = ""
    offerDate = Date()
    hasDeadline = false
    deadlineDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    notes = ""
  }
}
