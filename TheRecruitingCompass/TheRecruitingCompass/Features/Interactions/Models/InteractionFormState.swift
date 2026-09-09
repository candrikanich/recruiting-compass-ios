import Foundation

/// Form state for creating/editing an interaction
struct InteractionFormState {
  var schoolId: String = ""
  var coachId: String?
  var type: InteractionType?
  var direction: Direction = .outbound
  var occurredAt: Date = Date.now
  var subject: String = ""
  var content: String = ""
  var sentiment: Sentiment?
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

  init() {}

  /// Seeds a form for reviewing/editing an inbound-draft confirm, mirroring web's
  /// prefill in #678 — parser output becomes the starting point, not the final answer.
  init(fromDraft draft: InboundEmailDraft, fallbackSchoolId: String? = nil) {
    schoolId = draft.matchedSchoolId ?? fallbackSchoolId ?? ""
    coachId = draft.matchedCoachId
    type = .email
    direction = .inbound
    occurredAt = Self.draftDateFormatter.date(from: draft.occurredAt)
      ?? ISO8601DateFormatter().date(from: draft.occurredAt)
      ?? .now
    subject = draft.subject ?? ""
    content = draft.bodyText ?? ""
  }

  private static let draftDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

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
