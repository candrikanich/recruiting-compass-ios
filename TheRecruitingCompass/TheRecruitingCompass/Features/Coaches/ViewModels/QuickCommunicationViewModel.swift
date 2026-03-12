import Foundation
import OSLog
import SwiftUI

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "QuickCommunicationViewModel"
)

/// Context passed when presenting Quick Communication for a coach.
struct QuickCommunicationContext: Identifiable {
  let coach: Coach
  let schoolName: String?

  var id: String { coach.id }
}

@Observable
@MainActor
final class QuickCommunicationViewModel {
  var templates: [CommunicationTemplate] = []
  var selectedTemplate: CommunicationTemplate?
  var isLoading = false
  var errorMessage: String?

  let coach: Coach
  let schoolName: String?

  private let templatesService: any CommunicationTemplatesServicing

  var recipientLine: String {
    "\(coach.fullName) – \(coach.role.displayName)"
  }

  var emailTemplates: [CommunicationTemplate] {
    templates.filter { $0.type == .email }
  }

  var textTemplates: [CommunicationTemplate] {
    templates.filter { $0.type == .text }
  }

  /// Body with template variables substituted for this coach/school. Uses selected template or empty.
  var filledBody: String {
    guard let template = selectedTemplate else { return "" }
    return template.bodyFilled(with: substitutionValues)
  }

  /// Values available in this context (coach and school). Omit keys when value is nil or empty so template falls back to [Variable Name].
  private var substitutionValues: [String: String] {
    var result: [String: String] = ["coach_name": coach.fullName]
    if let name = schoolName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
      result["school_name"] = name
    }
    return result
  }

  init(
    coach: Coach,
    schoolName: String? = nil,
    templatesService: (any CommunicationTemplatesServicing)? = nil
  ) {
    self.coach = coach
    self.schoolName = schoolName
    self.templatesService = templatesService ?? CommunicationTemplatesServiceImpl()
  }

  func loadTemplates() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      templates = try await templatesService.fetchTemplates()
      if selectedTemplate != nil, !templates.contains(where: { $0.id == selectedTemplate?.id }) {
        selectedTemplate = nil
      }
      logger.info("Loaded \(self.templates.count) templates for quick communication")
    } catch {
      logger.error("Failed to load templates: \(error.localizedDescription)")
      errorMessage = "Failed to load templates. Please try again."
    }
  }

  func selectTemplate(_ template: CommunicationTemplate?) {
    selectedTemplate = template
  }

  /// Maximum body length for mailto/sms URLs. Launch Services fails (-10814) when URLs exceed system limits.
  private static let maxURLBodyLength = 1500

  /// URL to open Mail with pre-filled recipient and optional body. Returns nil if coach has no email.
  /// Body is truncated if it exceeds system URL length limits (Launch Services -10814).
  func mailtoURL() -> URL? {
    guard let email = coach.email?.trimmingCharacters(in: .whitespaces), !email.isEmpty else { return nil }
    var components = URLComponents(string: "mailto:\(email)")
    if !filledBody.isEmpty {
      let body = truncateBodyForURL(filledBody)
      components?.queryItems = [URLQueryItem(name: "body", value: body)]
    }
    return components?.url
  }

  /// URL to open Messages with optional body. Returns nil if coach has no phone.
  /// Body is truncated if it exceeds system URL length limits.
  func smsURL() -> URL? {
    guard let phone = coach.phone else { return nil }
    let cleaned = phone.filter { $0.isNumber || $0 == "+" }
    guard !cleaned.isEmpty else { return nil }
    var components = URLComponents(string: "sms:\(cleaned)")
    if !filledBody.isEmpty {
      let body = truncateBodyForURL(filledBody)
      components?.queryItems = [URLQueryItem(name: "body", value: body)]
    }
    return components?.url
  }

  private func truncateBodyForURL(_ body: String) -> String {
    if body.count <= Self.maxURLBodyLength { return body }
    let trimmed = String(body.prefix(Self.maxURLBodyLength - 30))
    return trimmed.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n[Message truncated — full text in app]"
  }


}
