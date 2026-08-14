import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "CommunicationTemplatesService"
)

/// True when an error indicates the templates table is absent (feature-flag-off tolerance).
/// Web returns [] on PGRST205; mirror that so an un-migrated backend degrades, not crashes.
func isMissingTableError(_ error: Error) -> Bool {
  let text = error.localizedDescription.lowercased()
  return text.contains("pgrst205")
    || (text.contains("communication_templates") && text.contains("does not exist"))
}

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
  let userId: String

  enum CodingKeys: String, CodingKey {
    case name, type, body
    case userId = "user_id"
  }
}

/// Payload for update only; omits user_id so ownership is not changed.
private struct TemplateUpdatePayload: Encodable {
  let name: String
  let type: String
  let body: String
}

final class CommunicationTemplatesServiceImpl: CommunicationTemplatesServicing, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  func fetchTemplates() async throws -> [CommunicationTemplate] {
    logger.debug("Fetching communication templates")
    do {
      let userId = (try? await supabaseManager.client.auth.session.user.id.uuidString) ?? ""
      let orFilter = userId.isEmpty
        ? "is_predefined.eq.true"
        : "user_id.eq.\(userId),is_predefined.eq.true"
      let templates: [CommunicationTemplate] = try await supabaseManager.client
        .from("communication_templates")
        .select()
        .or(orFilter)
        .order("updated_at", ascending: false)
        .execute()
        .value
      logger.info("Fetched \(templates.count) templates")
      return templates
    } catch {
      if isMissingTableError(error) {
        logger.warning("communication_templates table absent; returning [] (fail-soft)")
        return []
      }
      logger.error("fetchTemplates failed: \(error.localizedDescription)")
      throw error
    }
  }

  func createTemplate(formData: TemplateFormData) async throws -> CommunicationTemplate {
    logger.debug("Creating template: \(formData.name)")
    do {
      let session = try await supabaseManager.client.auth.session
      let userId = session.user.id.uuidString
      let payload = makePayload(from: formData, userId: userId)
      let template: CommunicationTemplate = try await supabaseManager.client
        .from("communication_templates")
        .insert(payload)
        .select()
        .single()
        .execute()
        .value
      logger.info("Created template: \(template.id)")
      return template
    } catch {
      logger.error("createTemplate failed: \(error.localizedDescription)")
      throw error
    }
  }

  func updateTemplate(id: String, formData: TemplateFormData) async throws -> CommunicationTemplate {
    logger.debug("Updating template: \(id)")
    do {
      let payload = makeUpdatePayload(from: formData)
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
    } catch {
      logger.error("updateTemplate \(id) failed: \(error.localizedDescription)")
      throw error
    }
  }

  func deleteTemplate(id: String) async throws {
    logger.debug("Deleting template: \(id)")
    do {
      try await supabaseManager.client
        .from("communication_templates")
        .delete()
        .eq("id", value: id)
        .execute()
      logger.info("Deleted template: \(id)")
    } catch {
      logger.error("deleteTemplate \(id) failed: \(error.localizedDescription)")
      throw error
    }
  }

  private func makePayload(from formData: TemplateFormData, userId: String) -> TemplatePayload {
    TemplatePayload(
      name: formData.name.trimmingCharacters(in: .whitespaces),
      type: formData.type.rawValue,
      body: formData.body,
      userId: userId
    )
  }

  private func makeUpdatePayload(from formData: TemplateFormData) -> TemplateUpdatePayload {
    TemplateUpdatePayload(
      name: formData.name.trimmingCharacters(in: .whitespaces),
      type: formData.type.rawValue,
      body: formData.body
    )
  }
}
