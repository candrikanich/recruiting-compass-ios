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
  let phone: String?
  let athleticsUrl: String?
  let ncaaId: String?
  let status: String
  let statusChangedAt: String?
  let questionnaireCompleted: Bool
  let questionnaireCompletedAt: String?
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

  // Explicit memberwise init so adding `phone` (defaulted) does not break the
  // dozens of existing labeled call sites that predate the field.
  init(
    id: String,
    userId: String,
    name: String,
    location: String?,
    city: String?,
    state: String?,
    division: String?,
    conference: String?,
    ranking: Int?,
    isFavorite: Bool,
    website: String?,
    faviconUrl: String?,
    twitterHandle: String?,
    instagramHandle: String?,
    phone: String? = nil,
    athleticsUrl: String? = nil,
    ncaaId: String?,
    status: String,
    statusChangedAt: String?,
    questionnaireCompleted: Bool = false,
    questionnaireCompletedAt: String? = nil,
    notes: String?,
    pros: [String],
    cons: [String],
    offerDetails: OfferDetails?,
    academicInfo: AcademicInfo?,
    amenities: Amenities?,
    coachingPhilosophy: String?,
    coachingStyle: String?,
    recruitingApproach: String?,
    communicationStyle: String?,
    successMetrics: String?,
    familyUnitId: String,
    createdBy: String?,
    updatedBy: String?,
    createdAt: String,
    updatedAt: String
  ) {
    self.id = id
    self.userId = userId
    self.name = name
    self.location = location
    self.city = city
    self.state = state
    self.division = division
    self.conference = conference
    self.ranking = ranking
    self.isFavorite = isFavorite
    self.website = website
    self.faviconUrl = faviconUrl
    self.twitterHandle = twitterHandle
    self.instagramHandle = instagramHandle
    self.phone = phone
    self.athleticsUrl = athleticsUrl
    self.ncaaId = ncaaId
    self.status = status
    self.statusChangedAt = statusChangedAt
    self.questionnaireCompleted = questionnaireCompleted
    self.questionnaireCompletedAt = questionnaireCompletedAt
    self.notes = notes
    self.pros = pros
    self.cons = cons
    self.offerDetails = offerDetails
    self.academicInfo = academicInfo
    self.amenities = amenities
    self.coachingPhilosophy = coachingPhilosophy
    self.coachingStyle = coachingStyle
    self.recruitingApproach = recruitingApproach
    self.communicationStyle = communicationStyle
    self.successMetrics = successMetrics
    self.familyUnitId = familyUnitId
    self.createdBy = createdBy
    self.updatedBy = updatedBy
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case name, location, city, state, division, conference, ranking
    case isFavorite = "is_favorite"
    case website
    case faviconUrl = "favicon_url"
    case twitterHandle = "twitter_handle"
    case instagramHandle = "instagram_handle"
    case phone
    case athleticsUrl = "athletics_url"
    case ncaaId = "ncaa_id"
    case status
    case statusChangedAt = "status_changed_at"
    case questionnaireCompleted = "questionnaire_completed"
    case questionnaireCompletedAt = "questionnaire_completed_at"
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
      phone: phone,
      athleticsUrl: athleticsUrl,
      ncaaId: ncaaId,
      status: status,
      statusChangedAt: statusChangedAt,
      questionnaireCompleted: questionnaireCompleted,
      questionnaireCompletedAt: questionnaireCompletedAt,
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

  func with(academicInfo: AcademicInfo?) -> School {
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
      phone: phone,
      athleticsUrl: athleticsUrl,
      ncaaId: ncaaId,
      status: status,
      statusChangedAt: statusChangedAt,
      questionnaireCompleted: questionnaireCompleted,
      questionnaireCompletedAt: questionnaireCompletedAt,
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
      phone: phone,
      athleticsUrl: athleticsUrl,
      ncaaId: ncaaId,
      status: status,
      statusChangedAt: statusChangedAt,
      questionnaireCompleted: questionnaireCompleted,
      questionnaireCompletedAt: questionnaireCompletedAt,
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
      phone: phone,
      athleticsUrl: athleticsUrl,
      ncaaId: ncaaId,
      status: status,
      statusChangedAt: statusChangedAt,
      questionnaireCompleted: questionnaireCompleted,
      questionnaireCompletedAt: questionnaireCompletedAt,
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
      phone: phone,
      athleticsUrl: athleticsUrl,
      ncaaId: ncaaId,
      status: status,
      statusChangedAt: statusChangedAt,
      questionnaireCompleted: questionnaireCompleted,
      questionnaireCompletedAt: questionnaireCompletedAt,
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
      phone: phone,
      athleticsUrl: athleticsUrl,
      ncaaId: ncaaId,
      status: status,
      statusChangedAt: statusChangedAt,
      questionnaireCompleted: questionnaireCompleted,
      questionnaireCompletedAt: questionnaireCompletedAt,
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
      phone: phone,
      athleticsUrl: athleticsUrl,
      ncaaId: ncaaId,
      status: status,
      statusChangedAt: statusChangedAt,
      questionnaireCompleted: questionnaireCompleted,
      questionnaireCompletedAt: questionnaireCompletedAt,
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

  func with(questionnaireCompleted: Bool) -> School {
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
      phone: phone,
      athleticsUrl: athleticsUrl,
      ncaaId: ncaaId,
      status: status,
      statusChangedAt: statusChangedAt,
      questionnaireCompleted: questionnaireCompleted,
      questionnaireCompletedAt: questionnaireCompleted
        ? ISO8601DateFormatter().string(from: Date())
        : nil,
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
    phone = try container.decodeIfPresent(String.self, forKey: .phone)
    athleticsUrl = try container.decodeIfPresent(String.self, forKey: .athleticsUrl)
    ncaaId = try container.decodeIfPresent(String.self, forKey: .ncaaId)
    status = try container.decode(String.self, forKey: .status)
    statusChangedAt = try container.decodeIfPresent(String.self, forKey: .statusChangedAt)
    questionnaireCompleted = try container.decodeIfPresent(Bool.self, forKey: .questionnaireCompleted) ?? false
    questionnaireCompletedAt = try container.decodeIfPresent(String.self, forKey: .questionnaireCompletedAt)
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
