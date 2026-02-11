import Foundation

/// State model for the coach form
struct CoachFormState: Sendable {
  var selectedSchoolId: String?
  var role: CoachRole?
  var firstName: String
  var lastName: String
  var email: String
  var phone: String
  var twitterHandle: String
  var instagramHandle: String
  var notes: String

  var isSchoolSelected: Bool {
    selectedSchoolId != nil
  }

  var isSubmittable: Bool {
    isSchoolSelected &&
    role != nil &&
    !firstName.isEmpty &&
    !lastName.isEmpty
  }

  init(
    selectedSchoolId: String? = nil,
    role: CoachRole? = nil,
    firstName: String = "",
    lastName: String = "",
    email: String = "",
    phone: String = "",
    twitterHandle: String = "",
    instagramHandle: String = "",
    notes: String = ""
  ) {
    self.selectedSchoolId = selectedSchoolId
    self.role = role
    self.firstName = firstName
    self.lastName = lastName
    self.email = email
    self.phone = phone
    self.twitterHandle = twitterHandle
    self.instagramHandle = instagramHandle
    self.notes = notes
  }
}
