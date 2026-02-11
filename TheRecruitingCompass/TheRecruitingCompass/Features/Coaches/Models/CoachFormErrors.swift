import Foundation

/// Error state model for the coach form
struct CoachFormErrors: Sendable {
  var role: String?
  var firstName: String?
  var lastName: String?
  var email: String?
  var phone: String?
  var twitterHandle: String?
  var instagramHandle: String?
  var notes: String?

  var hasErrors: Bool {
    [role, firstName, lastName, email, phone,
     twitterHandle, instagramHandle, notes]
      .contains(where: { $0 != nil })
  }

  var allErrors: [String] {
    [role, firstName, lastName, email, phone,
     twitterHandle, instagramHandle, notes]
      .compactMap { $0 }
  }

  static let empty = CoachFormErrors()

  init(
    role: String? = nil,
    firstName: String? = nil,
    lastName: String? = nil,
    email: String? = nil,
    phone: String? = nil,
    twitterHandle: String? = nil,
    instagramHandle: String? = nil,
    notes: String? = nil
  ) {
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
