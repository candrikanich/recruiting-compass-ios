import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "CommunicationTemplatesService"
)

protocol CommunicationTemplatesServicing: Sendable {
  func fetchTemplates() async throws -> [CommunicationTemplate]
  func createTemplate(formData: TemplateFormData) async throws -> CommunicationTemplate
  func updateTemplate(id: String, formData: TemplateFormData) async throws -> CommunicationTemplate
  func deleteTemplate(id: String) async throws
}

private struct TemplatePayload: Encodable {
  let name: String
  let type: String
  let body: String
  let variables: [String]
}

final class CommunicationTemplatesServiceImpl: CommunicationTemplatesServicing, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  func fetchTemplates() async throws -> [CommunicationTemplate] {
    logger.info("Fetching communication templates")

    let templates: [CommunicationTemplate] = try await supabaseManager.client
      .from("communication_templates")
      .select()
      .order("updated_at", ascending: false)
      .execute()
      .value

    logger.info("Fetched \(templates.count) templates")
    return templates
  }

  func createTemplate(formData: TemplateFormData) async throws -> CommunicationTemplate {
    logger.info("Creating template: \(formData.name)")

    let payload = makePayload(from: formData)

    let template: CommunicationTemplate = try await supabaseManager.client
      .from("communication_templates")
      .insert(payload)
      .select()
      .single()
      .execute()
      .value

    logger.info("Created template: \(template.id)")
    return template
  }

  func updateTemplate(id: String, formData: TemplateFormData) async throws -> CommunicationTemplate {
    logger.info("Updating template: \(id)")

    let payload = makePayload(from: formData)

    let template: CommunicationTemplate = try await supabaseManager.client
      .from("communication_templates")
      .update(payload)
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Updated template: \(id)")
    return template
  }

  func deleteTemplate(id: String) async throws {
    logger.info("Deleting template: \(id)")

    try await supabaseManager.client
      .from("communication_templates")
      .delete()
      .eq("id", value: id)
      .execute()

    logger.info("Deleted template: \(id)")
  }

  private func makePayload(from formData: TemplateFormData) -> TemplatePayload {
    TemplatePayload(
      name: formData.name.trimmingCharacters(in: .whitespaces),
      type: formData.type.rawValue,
      body: formData.body,
      variables: extractVariables(from: formData.body)
    )
  }

  private func extractVariables(from body: String) -> [String] {
    let pattern = #"\{\{(\w+)\}\}"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(body.startIndex..., in: body)
    let matches = regex.matches(in: body, range: range)
    let variables = matches.compactMap { match -> String? in
      guard let varRange = Range(match.range(at: 1), in: body) else { return nil }
      return String(body[varRange])
    }
    return Array(Set(variables)).sorted()
  }
}
