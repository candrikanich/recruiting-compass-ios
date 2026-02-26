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

  /// Values available in this context (coach and school). Other variables will show as [Variable Name].
  private var substitutionValues: [String: String] {
    [
      "coach_name": coach.fullName,
      "school_name": schoolName ?? "",
    ]
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

  /// URL to open Mail with pre-filled recipient and optional body. Returns nil if coach has no email.
  func mailtoURL() -> URL? {
    guard let email = coach.email?.trimmingCharacters(in: .whitespaces), !email.isEmpty else { return nil }
    var components = URLComponents(string: "mailto:\(email)")
    if !filledBody.isEmpty {
      components?.queryItems = [URLQueryItem(name: "body", value: filledBody)]
    }
    return components?.url
  }

  /// URL to open Messages with optional body. Returns nil if coach has no phone.
  func smsURL() -> URL? {
    guard let phone = coach.phone else { return nil }
    let cleaned = phone.filter { $0.isNumber || $0 == "+" }
    guard !cleaned.isEmpty else { return nil }
    var components = URLComponents(string: "sms:\(cleaned)")
    if !filledBody.isEmpty {
      components?.queryItems = [URLQueryItem(name: "body", value: filledBody)]
    }
    return components?.url
  }
}
