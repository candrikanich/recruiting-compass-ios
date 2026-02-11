import Foundation

/// State model for the school form
struct SchoolFormState: Sendable {
  static let notesCharacterLimit = 5000
  static let nameMinimumLength = 2

  var name: String
  var location: String
  var city: String
  var state: String
  var division: Division?
  var conference: String
  var website: String
  var twitterHandle: String
  var instagramHandle: String
  var notes: String
  var status: SchoolStatus
  var isAutocompleteEnabled: Bool

  var isSubmittable: Bool {
    name.trimmingCharacters(in: .whitespacesAndNewlines).count >= Self.nameMinimumLength
  }

  var autoFilledFields: Set<AutoFillableField> {
    []
  }

  init(
    name: String = "",
    location: String = "",
    city: String = "",
    state: String = "",
    division: Division? = nil,
    conference: String = "",
    website: String = "",
    twitterHandle: String = "",
    instagramHandle: String = "",
    notes: String = "",
    status: SchoolStatus = .interested,
    isAutocompleteEnabled: Bool = true
  ) {
    self.name = name
    self.location = location
    self.city = city
    self.state = state
    self.division = division
    self.conference = conference
    self.website = website
    self.twitterHandle = twitterHandle
    self.instagramHandle = instagramHandle
    self.notes = notes
    self.status = status
    self.isAutocompleteEnabled = isAutocompleteEnabled
  }
}
