import Foundation

struct SchoolPreference: Codable, Equatable, Identifiable, Sendable {
  let id: String
  var category: PreferencePreferenceCategory
  var type: String
  var value: AnyCodableValue
  var priority: Int
  var isDealbreaker: Bool

  enum CodingKeys: String, CodingKey {
    case id
    case category
    case type
    case value
    case priority
    case isDealbreaker = "is_dealbreaker"
  }
}
