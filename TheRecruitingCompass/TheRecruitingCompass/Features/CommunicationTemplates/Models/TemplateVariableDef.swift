import Foundation

enum VariableSourceType: String, Codable, Sendable {
  case column, computed, authored, system, unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = VariableSourceType(rawValue: raw) ?? .unknown
  }
}

/// One `template_variables` registry row (global; RLS `SELECT USING (true)`).
struct TemplateVariableDef: Codable, Sendable, Identifiable {
  let key: String
  let label: String
  let description: String?
  let category: String
  let sourceType: VariableSourceType
  let sourcePath: String?
  let isRequiredDefault: Bool
  let example: String?
  let sortOrder: Int?

  var id: String { key }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    key = try c.decode(String.self, forKey: .key)
    label = try c.decode(String.self, forKey: .label)
    description = try c.decodeIfPresent(String.self, forKey: .description)
    category = try c.decode(String.self, forKey: .category)
    sourceType = try c.decodeIfPresent(VariableSourceType.self, forKey: .sourceType) ?? .unknown
    sourcePath = try c.decodeIfPresent(String.self, forKey: .sourcePath)
    isRequiredDefault = try c.decodeIfPresent(Bool.self, forKey: .isRequiredDefault) ?? false
    example = try c.decodeIfPresent(String.self, forKey: .example)
    sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder)
  }

  init(key: String, label: String, category: String, sourceType: VariableSourceType,
       sourcePath: String? = nil, isRequiredDefault: Bool = false,
       description: String? = nil, example: String? = nil, sortOrder: Int? = nil) {
    self.key = key
    self.label = label
    self.description = description
    self.category = category
    self.sourceType = sourceType
    self.sourcePath = sourcePath
    self.isRequiredDefault = isRequiredDefault
    self.example = example
    self.sortOrder = sortOrder
  }

  enum CodingKeys: String, CodingKey {
    case key, label, description, category, example
    case sourceType = "source_type"
    case sourcePath = "source_path"
    case isRequiredDefault = "is_required_default"
    case sortOrder = "sort_order"
  }
}
