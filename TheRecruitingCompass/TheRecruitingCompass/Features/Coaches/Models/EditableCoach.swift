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

  static var empty: EditableCoach {
    EditableCoach(
      firstName: "",
      lastName: "",
      email: "",
      phone: "",
      position: "assistant",
      twitterHandle: "",
      instagramHandle: "",
      notes: ""
    )
  }

  init(firstName: String, lastName: String, email: String, phone: String, position: String, twitterHandle: String, instagramHandle: String, notes: String) {
    self.firstName = firstName
    self.lastName = lastName
    self.email = email
    self.phone = phone
    self.position = position
    self.twitterHandle = twitterHandle
    self.instagramHandle = instagramHandle
    self.notes = notes
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
  }

  func toUpdateRequest() -> CoachUpdateRequest {
    CoachUpdateRequest(
      firstName: firstName,
      lastName: lastName,
      email: email.isEmpty ? nil : email,
      phone: phone.isEmpty ? nil : phone,
      position: position,
      twitterHandle: twitterHandle.isEmpty ? nil : twitterHandle,
      instagramHandle: instagramHandle.isEmpty ? nil : instagramHandle,
      notes: DataSanitizer.nilIfEmpty(DataSanitizer.stripHtmlTags(notes))
    )
  }
}
