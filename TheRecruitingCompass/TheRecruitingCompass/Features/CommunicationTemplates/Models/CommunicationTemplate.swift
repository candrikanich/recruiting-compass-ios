import Foundation
import SwiftUI

struct CommunicationTemplate: Codable, Identifiable, Sendable {
  let id: String
  let userId: String
  let name: String
  let type: TemplateType
  let body: String
  let variables: [String]?
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
    case id, name, type, body, variables
    case userId = "user_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

enum TemplateType: String, Codable, CaseIterable, Sendable {
  case email
  case text
  case twitter

  var displayName: String {
    switch self {
    case .email: return "Email"
    case .text: return "Text"
    case .twitter: return "Twitter"
    }
  }

  var color: Color {
    switch self {
    case .email: return .accentBlue
    case .text: return .successGreen
    case .twitter: return .cyan
    }
  }
}

struct TemplateVariable {
  let name: String
  let key: String

  static let all: [TemplateVariable] = [
    TemplateVariable(name: "Coach Name", key: "coach_name"),
    TemplateVariable(name: "Athlete Name", key: "athlete_name"),
    TemplateVariable(name: "School Name", key: "school_name"),
    TemplateVariable(name: "Sport", key: "sport"),
    TemplateVariable(name: "Position", key: "position"),
    TemplateVariable(name: "Graduation Year", key: "grad_year"),
    TemplateVariable(name: "High School", key: "high_school"),
  ]
}

struct TemplateFormData {
  var name: String = ""
  var type: TemplateType = .email
  var body: String = ""

  var isValid: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty
      && !body.trimmingCharacters(in: .whitespaces).isEmpty
  }

  init() {}

  init(from template: CommunicationTemplate) {
    self.name = template.name
    self.type = template.type
    self.body = template.body
  }
}

// MARK: - Template variable substitution (e.g. for Quick Communication)

extension CommunicationTemplate {

  /// Replaces `{{key}}` placeholders in `body` with values from the given dictionary.
  /// Keys not present in the dictionary are replaced with a placeholder like `[Variable Name]` using TemplateVariable names when available.
  func bodyFilled(with values: [String: String]) -> String {
    Self.substituteVariables(in: body, values: values)
  }

  /// Substitutes `{{key}}` placeholders in a string. Unknown keys become `[Display Name]` when in TemplateVariable.all.
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
        ?? "{{\(key)}}"
      let placeholderRange = Range(match.range, in: result)!
      result.replaceSubrange(placeholderRange, with: replacement)
    }
    return result
  }
}
