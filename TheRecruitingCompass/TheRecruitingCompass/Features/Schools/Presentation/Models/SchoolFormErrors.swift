import Foundation

/// Error state model for the school form
struct SchoolFormErrors: Sendable {
  var name: String?
  var location: String?
  var city: String?
  var state: String?
  var division: String?
  var conference: String?
  var website: String?
  var twitterHandle: String?
  var instagramHandle: String?
  var notes: String?
  var status: String?

  var hasErrors: Bool {
    [name, location, city, state, division, conference,
     website, twitterHandle, instagramHandle, notes, status]
      .contains(where: { $0 != nil })
  }

  var allErrors: [String] {
    [name, location, city, state, division, conference,
     website, twitterHandle, instagramHandle, notes, status]
      .compactMap { $0 }
  }

  static let empty = SchoolFormErrors()

  init(
    name: String? = nil,
    location: String? = nil,
    city: String? = nil,
    state: String? = nil,
    division: String? = nil,
    conference: String? = nil,
    website: String? = nil,
    twitterHandle: String? = nil,
    instagramHandle: String? = nil,
    notes: String? = nil,
    status: String? = nil
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
  }
}
