import Foundation

struct Amenities: Codable, Equatable, Sendable {
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
