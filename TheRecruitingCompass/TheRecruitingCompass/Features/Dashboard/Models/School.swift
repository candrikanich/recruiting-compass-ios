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

  /// Memberwise initializer for previews and tests (Swift no longer auto-synthesizes when custom Decodable exists).
  init(
    gpaRequirement: Double? = nil,
    satRequirement: Int? = nil,
    actRequirement: Int? = nil,
    additionalRequirements: [String]? = nil,
    address: String? = nil,
    city: String? = nil,
    state: String? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil,
    studentSize: Int? = nil,
    baseballFacilityAddress: String? = nil,
    mascot: String? = nil,
    undergradSize: String? = nil,
    carnegieSize: String? = nil,
    tuitionInState: Double? = nil,
    tuitionOutOfState: Double? = nil,
    admissionRate: Double? = nil,
    distanceFromHome: Double? = nil
  ) {
    self.gpaRequirement = gpaRequirement
    self.satRequirement = satRequirement
    self.actRequirement = actRequirement
    self.additionalRequirements = additionalRequirements
    self.address = address
    self.city = city
    self.state = state
    self.latitude = latitude
    self.longitude = longitude
    self.studentSize = studentSize
    self.baseballFacilityAddress = baseballFacilityAddress
    self.mascot = mascot
    self.undergradSize = undergradSize
    self.carnegieSize = carnegieSize
    self.tuitionInState = tuitionInState
    self.tuitionOutOfState = tuitionOutOfState
    self.admissionRate = admissionRate
    self.distanceFromHome = distanceFromHome
  }

  /// Decodes from either a JSON object (current format) or a JSON string (legacy format from older merge).
  init(from decoder: Decoder) throws {
    if let keyed = try? decoder.container(keyedBy: CodingKeys.self) {
      gpaRequirement = try keyed.decodeIfPresent(Double.self, forKey: .gpaRequirement)
      satRequirement = try keyed.decodeIfPresent(Int.self, forKey: .satRequirement)
      actRequirement = try keyed.decodeIfPresent(Int.self, forKey: .actRequirement)
      additionalRequirements = try keyed.decodeIfPresent([String].self, forKey: .additionalRequirements)
      address = try keyed.decodeIfPresent(String.self, forKey: .address)
      city = try keyed.decodeIfPresent(String.self, forKey: .city)
      state = try keyed.decodeIfPresent(String.self, forKey: .state)
      latitude = try keyed.decodeIfPresent(Double.self, forKey: .latitude)
      longitude = try keyed.decodeIfPresent(Double.self, forKey: .longitude)
      studentSize = try keyed.decodeIfPresent(Int.self, forKey: .studentSize)
      baseballFacilityAddress = try keyed.decodeIfPresent(String.self, forKey: .baseballFacilityAddress)
      mascot = try keyed.decodeIfPresent(String.self, forKey: .mascot)
      undergradSize = try keyed.decodeIfPresent(String.self, forKey: .undergradSize)
      carnegieSize = try keyed.decodeIfPresent(String.self, forKey: .carnegieSize)
      tuitionInState = try keyed.decodeIfPresent(Double.self, forKey: .tuitionInState)
      tuitionOutOfState = try keyed.decodeIfPresent(Double.self, forKey: .tuitionOutOfState)
      admissionRate = try keyed.decodeIfPresent(Double.self, forKey: .admissionRate)
      distanceFromHome = try keyed.decodeIfPresent(Double.self, forKey: .distanceFromHome)
      return
    }
    // Legacy: academic_info stored as a JSON string (e.g. from older merge or other clients)
    let single = try decoder.singleValueContainer()
    let jsonString = try single.decode(String.self)
    guard let data = jsonString.data(using: .utf8) else {
      throw DecodingError.dataCorruptedError(
        in: single,
        debugDescription: "academic_info string is not valid UTF-8"
      )
    }
    let decoded = try JSONDecoder().decode(AcademicInfo.self, from: data)
    gpaRequirement = decoded.gpaRequirement
    satRequirement = decoded.satRequirement
    actRequirement = decoded.actRequirement
    additionalRequirements = decoded.additionalRequirements
    address = decoded.address
    city = decoded.city
    state = decoded.state
    latitude = decoded.latitude
    longitude = decoded.longitude
    studentSize = decoded.studentSize
    baseballFacilityAddress = decoded.baseballFacilityAddress
    mascot = decoded.mascot
    undergradSize = decoded.undergradSize
    carnegieSize = decoded.carnegieSize
    tuitionInState = decoded.tuitionInState
    tuitionOutOfState = decoded.tuitionOutOfState
    admissionRate = decoded.admissionRate
    distanceFromHome = decoded.distanceFromHome
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
    fitScore = try container.decodeIfPresent(Double.self, forKey: .fitScore)
    fitTier = try container.decodeIfPresent(String.self, forKey: .fitTier)
    familyUnitId = try container.decode(String.self, forKey: .familyUnitId)
    createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
    updatedBy = try container.decodeIfPresent(String.self, forKey: .updatedBy)
    createdAt = try container.decode(String.self, forKey: .createdAt)
    updatedAt = try container.decode(String.self, forKey: .updatedAt)
  }
}
