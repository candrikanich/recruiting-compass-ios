import Foundation

struct EditableCoach {
  var firstName: String
  var lastName: String
  var email: String
  var phone: String
  var position: String
  var twitterHandle: String
  var instagramHandle: String
  var notes: String
  var tags: [String]
  var source: String
  var nextContactDate: Date?
  var followUpThresholdDays: Int

  private static let isoDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
  }()

  static var empty: EditableCoach {
    EditableCoach(
      firstName: "",
      lastName: "",
      email: "",
      phone: "",
      position: "assistant",
      twitterHandle: "",
      instagramHandle: "",
      notes: "",
      tags: [],
      source: "",
      nextContactDate: nil,
      followUpThresholdDays: 21
    )
  }

  init(
    firstName: String,
    lastName: String,
    email: String,
    phone: String,
    position: String,
    twitterHandle: String,
    instagramHandle: String,
    notes: String,
    tags: [String] = [],
    source: String = "",
    nextContactDate: Date? = nil,
    followUpThresholdDays: Int = 21
  ) {
    self.firstName = firstName
    self.lastName = lastName
    self.email = email
    self.phone = phone
    self.position = position
    self.twitterHandle = twitterHandle
    self.instagramHandle = instagramHandle
    self.notes = notes
    self.tags = tags
    self.source = source
    self.nextContactDate = nextContactDate
    self.followUpThresholdDays = followUpThresholdDays
  }

  init(from coach: Coach) {
    self.firstName = coach.firstName
    self.lastName = coach.lastName
    self.email = coach.email ?? ""
    self.phone = coach.phone ?? ""
    self.position = coach.position ?? "assistant"
    self.twitterHandle = coach.twitterHandle ?? ""
    self.instagramHandle = coach.instagramHandle ?? ""
    self.notes = coach.notes ?? ""
    self.tags = coach.tags
    self.source = coach.source ?? ""
    self.followUpThresholdDays = coach.followUpThresholdDays ?? 21
    if let dateString = coach.nextContactDate {
      self.nextContactDate = EditableCoach.isoDateFormatter.date(from: dateString)
    } else {
      self.nextContactDate = nil
    }
  }

  func toUpdateRequest() -> CoachUpdateRequest {
    let nextContactDateString = nextContactDate.map { EditableCoach.isoDateFormatter.string(from: $0) }
    return CoachUpdateRequest(
      firstName: firstName,
      lastName: lastName,
      email: email.isEmpty ? nil : email,
      phone: phone.isEmpty ? nil : phone,
      position: position,
      twitterHandle: twitterHandle.isEmpty ? nil : twitterHandle,
      instagramHandle: instagramHandle.isEmpty ? nil : instagramHandle,
      notes: DataSanitizer.nilIfEmpty(DataSanitizer.stripHtmlTags(notes)),
      nextContactDate: nextContactDateString,
      followUpThresholdDays: followUpThresholdDays,
      tags: CoachTagsValidator.sanitize(tags),
      source: CoachTagsValidator.sanitizeSource(source)
    )
  }
}
