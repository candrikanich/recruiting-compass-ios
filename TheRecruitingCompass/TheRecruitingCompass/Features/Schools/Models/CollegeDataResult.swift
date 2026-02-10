import Foundation

/// Result from College Scorecard API lookup
struct CollegeDataResult: Codable, Sendable {
  let id: String
  let name: String
  let website: String?
  let address: String?
  let city: String?
  let state: String?
  let studentSize: Int?
  let carnegieSize: String?
  let admissionRate: Double?
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
    case admissionRate = "latest.admissions.admission_rate.overall"
    case tuitionInState = "latest.cost.tuition.in_state"
    case tuitionOutOfState = "latest.cost.tuition.out_of_state"
    case latitude = "location.lat"
    case longitude = "location.lon"
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
