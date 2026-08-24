import Foundation

struct CommunicationTemplate: Codable, Identifiable, Sendable {
  let id: String
  let userId: String
  let familyUnitId: String?
  let name: String
  let type: TemplateType
  let body: String
  let variables: [String]?
  let subject: String?
  let slug: String?
  let stage: String?
  let contactWindow: String?
  let requiredVariables: [String]?
  let sortOrder: Int?
  let isPredefined: Bool?
  let createdAt: String
  let updatedAt: String

  var typeDisplayName: String { type.displayName }

  var bodyPreview: String {
    let maxLength = 100
    return body.count > maxLength ? String(body.prefix(maxLength)) + "..." : body
  }

  var formattedDate: String {
    let parsed = Self.fractionalFormatter.date(from: createdAt)
      ?? Self.basicFormatter.date(from: createdAt)
    guard let date = parsed else { return createdAt }
    return date.formatted(date: .abbreviated, time: .omitted)
  }

  init(id: String, userId: String, name: String, type: TemplateType, body: String,
       variables: [String]?, createdAt: String, updatedAt: String,
       familyUnitId: String? = nil,
       subject: String? = nil, slug: String? = nil, stage: String? = nil,
       contactWindow: String? = nil, requiredVariables: [String]? = nil,
       sortOrder: Int? = nil, isPredefined: Bool? = nil) {
    self.id = id
    self.userId = userId
    self.familyUnitId = familyUnitId
    self.name = name
    self.type = type
    self.body = body
    self.variables = variables
    self.subject = subject
    self.slug = slug
    self.stage = stage
    self.contactWindow = contactWindow
    self.requiredVariables = requiredVariables
    self.sortOrder = sortOrder
    self.isPredefined = isPredefined
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    userId = try c.decodeIfPresent(String.self, forKey: .userId) ?? ""
    familyUnitId = try c.decodeIfPresent(String.self, forKey: .familyUnitId)
    name = try c.decode(String.self, forKey: .name)
    type = try c.decode(TemplateType.self, forKey: .type)
    body = try c.decode(String.self, forKey: .body)
    variables = try c.decodeIfPresent([String].self, forKey: .variables)
    subject = try c.decodeIfPresent(String.self, forKey: .subject)
    slug = try c.decodeIfPresent(String.self, forKey: .slug)
    stage = try c.decodeIfPresent(String.self, forKey: .stage)
    contactWindow = try c.decodeIfPresent(String.self, forKey: .contactWindow)
    requiredVariables = try c.decodeIfPresent([String].self, forKey: .requiredVariables)
    sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder)
    isPredefined = try c.decodeIfPresent(Bool.self, forKey: .isPredefined)
    createdAt = try c.decode(String.self, forKey: .createdAt)
    updatedAt = try c.decode(String.self, forKey: .updatedAt)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(userId, forKey: .userId)
    try c.encodeIfPresent(familyUnitId, forKey: .familyUnitId)
    try c.encode(name, forKey: .name)
    try c.encode(type, forKey: .type)
    try c.encode(body, forKey: .body)
    try c.encodeIfPresent(variables, forKey: .variables)
    try c.encodeIfPresent(subject, forKey: .subject)
    try c.encodeIfPresent(slug, forKey: .slug)
    try c.encodeIfPresent(stage, forKey: .stage)
    try c.encodeIfPresent(contactWindow, forKey: .contactWindow)
    try c.encodeIfPresent(requiredVariables, forKey: .requiredVariables)
    try c.encodeIfPresent(sortOrder, forKey: .sortOrder)
    try c.encodeIfPresent(isPredefined, forKey: .isPredefined)
    try c.encode(createdAt, forKey: .createdAt)
    try c.encode(updatedAt, forKey: .updatedAt)
  }

  private static let fractionalFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static let basicFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  enum CodingKeys: String, CodingKey {
    case id, name, type, body, variables, subject, slug, stage
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case contactWindow = "contact_window"
    case requiredVariables = "required_variables"
    case sortOrder = "sort_order"
    case isPredefined = "is_predefined"
  }
}

// MARK: - Template variable substitution (e.g. for Quick Communication)

extension CommunicationTemplate {

  /// Replaces `{{key}}` placeholders in `body` with values from the given dictionary.
  /// Keys not present in the dictionary are replaced with a placeholder like `[Variable Name]` using TemplateVariable names when available.
  func bodyFilled(with values: [String: String]) -> String {
    Self.substituteVariables(in: body, values: values)
  }

  /// Substitutes `{{key}}` placeholders in a string. Unknown keys become `[Display Name]` when in TemplateVariable.all, or `[key]` for unknown keys (to avoid re-matching and infinite loop).
  static func substituteVariables(in body: String, values: [String: String]) -> String {
    let keyToDisplayName: [String: String] = Dictionary(
      uniqueKeysWithValues: TemplateVariable.all.map { ($0.key, $0.name) }
    )

    var result = body
    let pattern = #"\{\{(\w+)\}\}"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }

    while true {
      let range = NSRange(result.startIndex..., in: result)
      guard let match = regex.firstMatch(in: result, options: [], range: range),
            let keyRange = Range(match.range(at: 1), in: result) else { break }
      let key = String(result[keyRange])
      let replacement = values[key]
        ?? keyToDisplayName[key].map { "[\($0)]" }
        ?? "[\(key)]"
      guard let placeholderRange = Range(match.range, in: result) else { break }
      result.replaceSubrange(placeholderRange, with: replacement)
    }
    return result
  }
}
