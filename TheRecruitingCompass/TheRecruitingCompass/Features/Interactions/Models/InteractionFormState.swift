import Foundation

/// Form state for creating/editing an interaction
struct InteractionFormState {
  var schoolId: String = ""
  var coachId: String? = nil
  var type: InteractionType? = nil
  var direction: Direction = .outbound
  var occurredAt: Date = Date.now
  var subject: String = ""
  var content: String = ""
  var sentiment: Sentiment? = nil
  var interestLevel: InterestLevel = .notSet
  var attachedFiles: [AttachmentFile] = []

  /// Form is valid if required fields are filled
  var isValid: Bool {
    !schoolId.isEmpty && type != nil
  }

  /// Interest calibration should be shown when direction is inbound and sentiment is positive/very positive
  var showsInterestCalibration: Bool {
    direction == .inbound && (sentiment == .positive || sentiment == .veryPositive)
  }

  /// Reset form to default state
  mutating func reset() {
    schoolId = ""
    coachId = nil
    type = nil
    direction = .outbound
    occurredAt = Date.now
    subject = ""
    content = ""
    sentiment = nil
    interestLevel = .notSet
    attachedFiles = []
  }
}
