import Foundation

/// One template-referenced variable, tagged authored-vs-profile-backed and resolved-or-not,
/// so the variables panel can render editable inputs, read-only rows, and missing-profile hints.
struct ReferencedVariable: Equatable, Identifiable {
  let key: String
  let label: String
  let sourceType: VariableSourceType
  let isAuthored: Bool
  let isResolved: Bool
  let resolvedValue: String?
  var id: String { key }
}

/// Pure: which registry variables a template references, in first-seen order across subject+body.
/// Tokens with no registry row are still returned (label = key, sourceType `.unknown`).
enum TemplateVariableExtractor {
  static func referenced(subject: String?, body: String,
                         registry: [TemplateVariableDef],
                         resolvedValues: [String: String]) -> [ReferencedVariable] {
    let text = [subject, body].compactMap { $0 }.joined(separator: "\n")
    let byKey = Dictionary(registry.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
    return TemplateResolver.findUnresolved(text).map { key in   // deduped, first-seen order
      let def = byKey[key]
      return ReferencedVariable(
        key: key,
        label: def.map { $0.label.isEmpty ? key : $0.label } ?? key,
        sourceType: def?.sourceType ?? .unknown,
        isAuthored: def?.sourceType == .authored,
        isResolved: resolvedValues[key] != nil,
        resolvedValue: resolvedValues[key])
    }
  }
}
