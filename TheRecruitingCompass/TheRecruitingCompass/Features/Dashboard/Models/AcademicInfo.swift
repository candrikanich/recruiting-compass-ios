import Foundation

struct AcademicInfo: Codable, Equatable, Sendable {
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
  let sat25th: Int?
  let sat75th: Int?
  let act25th: Int?
  let act75th: Int?

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
    case sat25th = "sat_25th"
    case sat75th = "sat_75th"
    case act25th = "act_25th"
    case act75th = "act_75th"
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
    distanceFromHome: Double? = nil,
    sat25th: Int? = nil,
    sat75th: Int? = nil,
    act25th: Int? = nil,
    act75th: Int? = nil
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
    self.sat25th = sat25th
    self.sat75th = sat75th
    self.act25th = act25th
    self.act75th = act75th
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
      sat25th = try keyed.decodeIfPresent(Int.self, forKey: .sat25th)
      sat75th = try keyed.decodeIfPresent(Int.self, forKey: .sat75th)
      act25th = try keyed.decodeIfPresent(Int.self, forKey: .act25th)
      act75th = try keyed.decodeIfPresent(Int.self, forKey: .act75th)
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
    sat25th = decoded.sat25th
    sat75th = decoded.sat75th
    act25th = decoded.act25th
    act75th = decoded.act75th
  }
}
