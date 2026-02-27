import Foundation

/// Result from College Scorecard API lookup
/// Mirrors web CollegeDataResult (useCollegeData.ts) for parity
struct CollegeDataResult: Codable, Sendable {
  let id: String
  let name: String
  let website: String?
  let address: String?
  let city: String?
  let state: String?
  let studentSize: Int?
  let carnegieSize: String?
  let enrollmentAll: Int?
  let admissionRate: Double?
  let studentFacultyRatio: Double?
  let tuitionInState: Double?
  let tuitionOutOfState: Double?
  let latitude: Double?
  let longitude: Double?

  enum CodingKeys: String, CodingKey {
    case id
    case name = "school.name"
    case website = "school.school_url"
    case address = "school.address"
    case city = "school.city"
    case state = "school.state"
    case studentSize = "latest.student.size"
    case carnegieSize = "school.carnegie_size_setting"
    case enrollmentAll = "enrollment.all"
    case admissionRate = "latest.admissions.admission_rate.overall"
    case studentFacultyRatio = "latest.student.student_faculty_ratio"
    case tuitionInState = "latest.cost.tuition.in_state"
    case tuitionOutOfState = "latest.cost.tuition.out_of_state"
    case latitude = "location.lat"
    case longitude = "location.lon"
  }

  /// Memberwise initializer for previews and tests (Swift no longer auto-synthesizes this when custom Decodable exists).
  init(
    id: String,
    name: String,
    website: String? = nil,
    address: String? = nil,
    city: String? = nil,
    state: String? = nil,
    studentSize: Int? = nil,
    carnegieSize: String? = nil,
    enrollmentAll: Int? = nil,
    admissionRate: Double? = nil,
    studentFacultyRatio: Double? = nil,
    tuitionInState: Double? = nil,
    tuitionOutOfState: Double? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil
  ) {
    self.id = id
    self.name = name
    self.website = website
    self.address = address
    self.city = city
    self.state = state
    self.studentSize = studentSize
    self.carnegieSize = carnegieSize
    self.enrollmentAll = enrollmentAll
    self.admissionRate = admissionRate
    self.studentFacultyRatio = studentFacultyRatio
    self.tuitionInState = tuitionInState
    self.tuitionOutOfState = tuitionOutOfState
    self.latitude = latitude
    self.longitude = longitude
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    // API returns id as integer (IPEDS unit ID); decode as Int or String and normalize to String
    if let intId = try? c.decode(Int.self, forKey: .id) {
      id = String(intId)
    } else if let stringId = try? c.decode(String.self, forKey: .id) {
      id = stringId
    } else {
      throw DecodingError.typeMismatch(
        String.self,
        DecodingError.Context(
          codingPath: [CodingKeys.id],
          debugDescription: "Expected id as Int or String"
        )
      )
    }
    name = try c.decode(String.self, forKey: .name)
    website = try c.decodeIfPresent(String.self, forKey: .website)
    address = try c.decodeIfPresent(String.self, forKey: .address)
    city = try c.decodeIfPresent(String.self, forKey: .city)
    state = try c.decodeIfPresent(String.self, forKey: .state)
    studentSize = try c.decodeIfPresent(Int.self, forKey: .studentSize)
    // API returns school.carnegie_size_setting as integer code (e.g. 14); accept Int or String
    if let intSize = try? c.decodeIfPresent(Int.self, forKey: .carnegieSize) {
      carnegieSize = String(intSize)
    } else {
      carnegieSize = try c.decodeIfPresent(String.self, forKey: .carnegieSize)
    }
    enrollmentAll = try c.decodeIfPresent(Int.self, forKey: .enrollmentAll)
    admissionRate = try c.decodeIfPresent(Double.self, forKey: .admissionRate)
    studentFacultyRatio = try Self.decodeDoubleOrInt(c, forKey: .studentFacultyRatio)
    // API may return tuition as Int (e.g. 37938) or Double
    tuitionInState = try Self.decodeDoubleOrInt(c, forKey: .tuitionInState)
    tuitionOutOfState = try Self.decodeDoubleOrInt(c, forKey: .tuitionOutOfState)
    latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
    longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
  }

  private static func decodeDoubleOrInt(_ c: KeyedDecodingContainer<CollegeDataResult.CodingKeys>, forKey key: CodingKeys) throws -> Double? {
    if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
    if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(i) }
    return nil
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(name, forKey: .name)
    try c.encodeIfPresent(website, forKey: .website)
    try c.encodeIfPresent(address, forKey: .address)
    try c.encodeIfPresent(city, forKey: .city)
    try c.encodeIfPresent(state, forKey: .state)
    try c.encodeIfPresent(studentSize, forKey: .studentSize)
    try c.encodeIfPresent(carnegieSize, forKey: .carnegieSize)
    try c.encodeIfPresent(enrollmentAll, forKey: .enrollmentAll)
    try c.encodeIfPresent(admissionRate, forKey: .admissionRate)
    try c.encodeIfPresent(studentFacultyRatio, forKey: .studentFacultyRatio)
    try c.encodeIfPresent(tuitionInState, forKey: .tuitionInState)
    try c.encodeIfPresent(tuitionOutOfState, forKey: .tuitionOutOfState)
    try c.encodeIfPresent(latitude, forKey: .latitude)
    try c.encodeIfPresent(longitude, forKey: .longitude)
  }
}

/// Errors that can occur during College Scorecard API lookup
enum CollegeDataError: LocalizedError {
  case nameTooShort
  case apiKeyMissing
  case invalidApiKey
  case rateLimited
  case schoolNotFound
  case invalidResponse
  case serverError(Int)
  case networkError(Error)

  var errorDescription: String? {
    switch self {
    case .nameTooShort:
      return "School name must be at least 3 characters"
    case .apiKeyMissing:
      return "College Scorecard API key is not configured"
    case .invalidApiKey:
      return "Invalid API key"
    case .rateLimited:
      return "Too many requests. Please try again in a few moments."
    case .schoolNotFound:
      return "School not found in College Scorecard database"
    case .invalidResponse:
      return "Invalid response from College Scorecard API"
    case .serverError(let code):
      return "Server error (\(code)). Please try again later."
    case .networkError(let error):
      return "Network error: \(error.localizedDescription)"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .nameTooShort:
      return "Try entering the full school name."
    case .apiKeyMissing:
      return "Contact support to configure API access."
    case .invalidApiKey:
      return "Contact support to update API credentials."
    case .rateLimited:
      return "Wait a few moments before trying again."
    case .schoolNotFound:
      return "Try different spelling or enter data manually."
    case .invalidResponse, .serverError:
      return "Try again later or enter data manually."
    case .networkError:
      return "Check your internet connection and try again."
    }
  }
}
