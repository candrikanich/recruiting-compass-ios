import Foundation

/// Request model for creating a new school
struct SchoolCreateRequest: Encodable, Sendable {
  let userId: String
  let familyUnitId: String
  let name: String
  let location: String?
  let city: String?
  let state: String?
  let division: String?
  let conference: String?
  let website: String?
  let twitterHandle: String?
  let instagramHandle: String?
  let ncaaId: String?
  let notes: String?
  let status: String
  let academicInfo: AcademicInfo?
  let faviconUrl: String?

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
    case name
    case location
    case city
    case state
    case division
    case conference
    case website
    case twitterHandle = "twitter_handle"
    case instagramHandle = "instagram_handle"
    case ncaaId = "ncaa_id"
    case notes
    case status
    case academicInfo = "academic_info"
    case faviconUrl = "favicon_url"
  }

  /// Throws `FamilyUnitID.MissingError` rather than build a payload with a blank `family_unit_id`.
  init(
    userId: String,
    familyUnitId: String?,
    name: String,
    location: String?,
    city: String?,
    state: String?,
    division: String?,
    conference: String?,
    website: String?,
    twitterHandle: String?,
    instagramHandle: String?,
    ncaaId: String?,
    notes: String?,
    status: String,
    academicInfo: AcademicInfo?,
    faviconUrl: String?
  ) throws {
    self.userId = userId
    self.familyUnitId = try FamilyUnitID.require(familyUnitId)
    self.name = name
    self.location = location
    self.city = city
    self.state = state
    self.division = division
    self.conference = conference
    self.website = website
    self.twitterHandle = twitterHandle
    self.instagramHandle = instagramHandle
    self.ncaaId = ncaaId
    self.notes = notes
    self.status = status
    self.academicInfo = academicInfo
    self.faviconUrl = faviconUrl
  }
}
