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
      notes: notes.isEmpty ? nil : notes,
      privateNotes: nil  // Updated separately
    )
  }
}
