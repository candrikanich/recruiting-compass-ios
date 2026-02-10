import Foundation
import CoreLocation

// MARK: - Nested Types

struct AcademicInfo: Codable, Sendable {
  let gpaRequirement: Double?
  let satRequirement: Int?
  let actRequirement: Int?
  let additionalRequirements: [String]?
  let address: String?
  let city: String?
  let state: String?
  let latitude: Double?
  let longitude: Double?
  let studentSize: Int?
  let baseballFacilityAddress: String?
  let mascot: String?
  let undergradSize: String?
  let carnegieSize: String?
  let tuitionInState: Double?
  let tuitionOutOfState: Double?
  let admissionRate: Double?
  let distanceFromHome: Double?

  enum CodingKeys: String, CodingKey {
    case gpaRequirement = "gpa_requirement"
    case satRequirement = "sat_requirement"
    case actRequirement = "act_requirement"
    case additionalRequirements = "additional_requirements"
    case address, city, state, latitude, longitude
    case studentSize = "student_size"
    case baseballFacilityAddress = "baseball_facility_address"
    case mascot
    case undergradSize = "undergrad_size"
    case carnegieSize = "carnegie_size"
    case tuitionInState = "tuition_in_state"
    case tuitionOutOfState = "tuition_out_of_state"
    case admissionRate = "admission_rate"
    case distanceFromHome = "distance_from_home"
  }
}

struct OfferDetails: Codable, Sendable {
  let terms: String?
  let startDate: String?
  let endDate: String?
  let conditions: [String]?
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case terms
    case startDate = "start_date"
    case endDate = "end_date"
    case conditions, notes
  }
}

struct Amenities: Codable, Sendable {
  let facilities: [String]?
  let housing: String?
  let dining: String?
  let medical: String?
  let equipment: String?
  let academicSupport: String?

  enum CodingKeys: String, CodingKey {
    case facilities, housing, dining, medical, equipment
    case academicSupport = "academic_support"
  }
}

// MARK: - School

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
  let priorityTier: String?
  let notes: String?
  let privateNotes: [String: String]?
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
  let fitScore: Double?
  let fitTier: String?
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
    case priorityTier = "priority_tier"
    case notes
    case privateNotes = "private_notes"
    case pros, cons
    case offerDetails = "offer_details"
    case academicInfo = "academic_info"
    case amenities
    case coachingPhilosophy = "coaching_philosophy"
    case coachingStyle = "coaching_style"
    case recruitingApproach = "recruiting_approach"
    case communicationStyle = "communication_style"
    case successMetrics = "success_metrics"
    case fitScore = "fit_score"
    case fitTier = "fit_tier"
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

  func privateNote(for userId: String) -> String? {
    privateNotes?[userId]
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
      priorityTier: priorityTier,
      notes: notes,
      privateNotes: privateNotes,
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
      fitScore: fitScore,
      fitTier: fitTier,
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
      priorityTier: priorityTier,
      notes: notes,
      privateNotes: privateNotes,
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
      fitScore: fitScore,
      fitTier: fitTier,
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
      priorityTier: priorityTier,
      notes: notes,
      privateNotes: privateNotes,
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
      fitScore: fitScore,
      fitTier: fitTier,
      familyUnitId: familyUnitId,
      createdBy: createdBy,
      updatedBy: updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  func with(privateNotes: [String: String]?) -> School {
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
      priorityTier: priorityTier,
      notes: notes,
      privateNotes: privateNotes,
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
      fitScore: fitScore,
      fitTier: fitTier,
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
      priorityTier: priorityTier,
      notes: notes,
      privateNotes: privateNotes,
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
      fitScore: fitScore,
      fitTier: fitTier,
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
      priorityTier: priorityTier,
      notes: notes,
      privateNotes: privateNotes,
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
      fitScore: fitScore,
      fitTier: fitTier,
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
      priorityTier: priorityTier,
      notes: notes,
      privateNotes: privateNotes,
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
      fitScore: fitScore,
      fitTier: fitTier,
      familyUnitId: familyUnitId,
      createdBy: createdBy,
      updatedBy: updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
