import Foundation
import CoreLocation

struct School: Codable, Identifiable, Sendable {
  let id: String
  let userId: String
  let name: String
  let location: String?
  let city: String?
  let state: String?
  let division: String?
  let conference: String?
  let ranking: Int?
  var isFavorite: Bool
  let website: String?
  let faviconUrl: String?
  let twitterHandle: String?
  let instagramHandle: String?
  let ncaaId: String?
  let status: String
  let statusChangedAt: String?
  let notes: String?
  let pros: [String]
  let cons: [String]
  let offerDetails: OfferDetails?
  let academicInfo: AcademicInfo?
  let amenities: Amenities?
  let coachingPhilosophy: String?
  let coachingStyle: String?
  let recruitingApproach: String?
  let communicationStyle: String?
  let successMetrics: String?
  let familyUnitId: String
  let createdBy: String?
  let updatedBy: String?
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case name, location, city, state, division, conference, ranking
    case isFavorite = "is_favorite"
    case website
    case faviconUrl = "favicon_url"
    case twitterHandle = "twitter_handle"
    case instagramHandle = "instagram_handle"
    case ncaaId = "ncaa_id"
    case status
    case statusChangedAt = "status_changed_at"
    case notes
    case pros, cons
    case offerDetails = "offer_details"
    case academicInfo = "academic_info"
    case amenities
    case coachingPhilosophy = "coaching_philosophy"
    case coachingStyle = "coaching_style"
    case recruitingApproach = "recruiting_approach"
    case communicationStyle = "communication_style"
    case successMetrics = "success_metrics"
    case familyUnitId = "family_unit_id"
    case createdBy = "created_by"
    case updatedBy = "updated_by"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }

  // MARK: - Computed Properties

  var initials: String {
    let words = name.split(separator: " ")
    if words.count >= 2 {
      let first = String(words[0].prefix(1))
      let second = String(words[1].prefix(1))
      return "\(first)\(second)".uppercased()
    }
    return String(name.prefix(2)).uppercased()
  }

  var size: SchoolSize? {
    guard let studentSize = academicInfo?.studentSize else { return nil }
    return SchoolSize.from(studentSize: studentSize)
  }

  func distanceTo(from coordinate: CLLocationCoordinate2D) -> Double? {
    guard let lat = academicInfo?.latitude,
          let lon = academicInfo?.longitude else {
      return nil
    }

    let schoolLocation = CLLocation(latitude: lat, longitude: lon)
    let fromLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

    let distanceInMeters = schoolLocation.distance(from: fromLocation)
    let distanceInMiles = distanceInMeters / 1609.34

    return distanceInMiles
  }

  // MARK: - Mutability Helpers

  func with(isFavorite: Bool) -> School {
    School(
      id: id,
      userId: userId,
      name: name,
      location: location,
      city: city,
      state: state,
      division: division,
      conference: conference,
      ranking: ranking,
      isFavorite: isFavorite,
      website: website,
      faviconUrl: faviconUrl,
      twitterHandle: twitterHandle,
      instagramHandle: instagramHandle,
      ncaaId: ncaaId,
      status: status,
      statusChangedAt: statusChangedAt,
      notes: notes,
      pros: pros,
      cons: cons,
      offerDetails: offerDetails,
      academicInfo: academicInfo,
      amenities: amenities,
      coachingPhilosophy: coachingPhilosophy,
      coachingStyle: coachingStyle,
      recruitingApproach: recruitingApproach,
      communicationStyle: communicationStyle,
      successMetrics: successMetrics,
      familyUnitId: familyUnitId,
      createdBy: createdBy,
      updatedBy: updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  func with(status: String) -> School {
    School(
      id: id,
      userId: userId,
      name: name,
      location: location,
      city: city,
      state: state,
      division: division,
      conference: conference,
      ranking: ranking,
      isFavorite: isFavorite,
      website: website,
      faviconUrl: faviconUrl,
      twitterHandle: twitterHandle,
      instagramHandle: instagramHandle,
      ncaaId: ncaaId,
      status: status,
      statusChangedAt: statusChangedAt,
      notes: notes,
      pros: pros,
      cons: cons,
      offerDetails: offerDetails,
      academicInfo: academicInfo,
      amenities: amenities,
      coachingPhilosophy: coachingPhilosophy,
      coachingStyle: coachingStyle,
      recruitingApproach: recruitingApproach,
      communicationStyle: communicationStyle,
      successMetrics: successMetrics,
      familyUnitId: familyUnitId,
      createdBy: createdBy,
      updatedBy: updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  func with(notes: String) -> School {
    School(
      id: id,
      userId: userId,
      name: name,
      location: location,
      city: city,
      state: state,
      division: division,
      conference: conference,
      ranking: ranking,
      isFavorite: isFavorite,
      website: website,
      faviconUrl: faviconUrl,
      twitterHandle: twitterHandle,
      instagramHandle: instagramHandle,
      ncaaId: ncaaId,
      status: status,
      statusChangedAt: statusChangedAt,
      notes: notes,
      pros: pros,
      cons: cons,
      offerDetails: offerDetails,
      academicInfo: academicInfo,
      amenities: amenities,
      coachingPhilosophy: coachingPhilosophy,
      coachingStyle: coachingStyle,
      recruitingApproach: recruitingApproach,
      communicationStyle: communicationStyle,
      successMetrics: successMetrics,
      familyUnitId: familyUnitId,
      createdBy: createdBy,
      updatedBy: updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  func with(pros: [String]) -> School {
    School(
      id: id,
      userId: userId,
      name: name,
      location: location,
      city: city,
      state: state,
      division: division,
      conference: conference,
      ranking: ranking,
      isFavorite: isFavorite,
      website: website,
      faviconUrl: faviconUrl,
      twitterHandle: twitterHandle,
      instagramHandle: instagramHandle,
      ncaaId: ncaaId,
      status: status,
      statusChangedAt: statusChangedAt,
      notes: notes,
      pros: pros,
      cons: cons,
      offerDetails: offerDetails,
      academicInfo: academicInfo,
      amenities: amenities,
      coachingPhilosophy: coachingPhilosophy,
      coachingStyle: coachingStyle,
      recruitingApproach: recruitingApproach,
      communicationStyle: communicationStyle,
      successMetrics: successMetrics,
      familyUnitId: familyUnitId,
      createdBy: createdBy,
      updatedBy: updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  func with(cons: [String]) -> School {
    School(
      id: id,
      userId: userId,
      name: name,
      location: location,
      city: city,
      state: state,
      division: division,
      conference: conference,
      ranking: ranking,
      isFavorite: isFavorite,
      website: website,
      faviconUrl: faviconUrl,
      twitterHandle: twitterHandle,
      instagramHandle: instagramHandle,
      ncaaId: ncaaId,
      status: status,
      statusChangedAt: statusChangedAt,
      notes: notes,
      pros: pros,
      cons: cons,
      offerDetails: offerDetails,
      academicInfo: academicInfo,
      amenities: amenities,
      coachingPhilosophy: coachingPhilosophy,
      coachingStyle: coachingStyle,
      recruitingApproach: recruitingApproach,
      communicationStyle: communicationStyle,
      successMetrics: successMetrics,
      familyUnitId: familyUnitId,
      createdBy: createdBy,
      updatedBy: updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  func with(website: String) -> School {
    School(
      id: id,
      userId: userId,
      name: name,
      location: location,
      city: city,
      state: state,
      division: division,
      conference: conference,
      ranking: ranking,
      isFavorite: isFavorite,
      website: website,
      faviconUrl: faviconUrl,
      twitterHandle: twitterHandle,
      instagramHandle: instagramHandle,
      ncaaId: ncaaId,
      status: status,
      statusChangedAt: statusChangedAt,
      notes: notes,
      pros: pros,
      cons: cons,
      offerDetails: offerDetails,
      academicInfo: academicInfo,
      amenities: amenities,
      coachingPhilosophy: coachingPhilosophy,
      coachingStyle: coachingStyle,
      recruitingApproach: recruitingApproach,
      communicationStyle: communicationStyle,
      successMetrics: successMetrics,
      familyUnitId: familyUnitId,
      createdBy: createdBy,
      updatedBy: updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

// MARK: - Decodable

extension School {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    userId = try container.decode(String.self, forKey: .userId)
    name = try container.decode(String.self, forKey: .name)
    location = try container.decodeIfPresent(String.self, forKey: .location)
    city = try container.decodeIfPresent(String.self, forKey: .city)
    state = try container.decodeIfPresent(String.self, forKey: .state)
    division = try container.decodeIfPresent(String.self, forKey: .division)
    conference = try container.decodeIfPresent(String.self, forKey: .conference)
    ranking = try container.decodeIfPresent(Int.self, forKey: .ranking)
    isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    website = try container.decodeIfPresent(String.self, forKey: .website)
    faviconUrl = try container.decodeIfPresent(String.self, forKey: .faviconUrl)
    twitterHandle = try container.decodeIfPresent(String.self, forKey: .twitterHandle)
    instagramHandle = try container.decodeIfPresent(String.self, forKey: .instagramHandle)
    ncaaId = try container.decodeIfPresent(String.self, forKey: .ncaaId)
    status = try container.decode(String.self, forKey: .status)
    statusChangedAt = try container.decodeIfPresent(String.self, forKey: .statusChangedAt)
    notes = try container.decodeIfPresent(String.self, forKey: .notes)
    pros = try container.decodeIfPresent([String].self, forKey: .pros) ?? []
    cons = try container.decodeIfPresent([String].self, forKey: .cons) ?? []
    offerDetails = try container.decodeIfPresent(OfferDetails.self, forKey: .offerDetails)
    academicInfo = try container.decodeIfPresent(AcademicInfo.self, forKey: .academicInfo)
    amenities = try container.decodeIfPresent(Amenities.self, forKey: .amenities)
    coachingPhilosophy = try container.decodeIfPresent(String.self, forKey: .coachingPhilosophy)
    coachingStyle = try container.decodeIfPresent(String.self, forKey: .coachingStyle)
    recruitingApproach = try container.decodeIfPresent(String.self, forKey: .recruitingApproach)
    communicationStyle = try container.decodeIfPresent(String.self, forKey: .communicationStyle)
    successMetrics = try container.decodeIfPresent(String.self, forKey: .successMetrics)
    familyUnitId = try container.decode(String.self, forKey: .familyUnitId)
    createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
    updatedBy = try container.decodeIfPresent(String.self, forKey: .updatedBy)
    createdAt = try container.decode(String.self, forKey: .createdAt)
    updatedAt = try container.decode(String.self, forKey: .updatedAt)
  }
}
