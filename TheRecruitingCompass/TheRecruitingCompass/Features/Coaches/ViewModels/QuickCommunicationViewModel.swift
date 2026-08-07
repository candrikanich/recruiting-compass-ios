import Foundation
import OSLog
import SwiftUI

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "QuickCommunicationViewModel"
)

@Observable
@MainActor
final class QuickCommunicationViewModel {

  nonisolated deinit {}
  var templates: [CommunicationTemplate] = []
  var selectedTemplate: CommunicationTemplate?
  var isLoading = false
  var errorMessage: String?

  /// Set true after a confirmed send is logged. Drives the parent success toast.
  var didLogSend = false
  /// Success toast copy for a confirmed, logged send (nil until one is logged).
  var successMessage: String?

  let coach: Coach
  let schoolName: String?

  /// Channel a confirmed send used, so logging picks the matching interaction type.
  enum SendChannel { case email, text }

  private let templatesService: any CommunicationTemplatesServicing
  private let interactionsService: any InteractionsManaging
  private let coachesService: any CoachesManaging
  private var loggedBy: String?
  private var familyUnitId: String?

  /// Supply the signed-in user + family context resolved from the environment at the
  /// presentation site (the sheet call sites don't inject the ViewModel). Safe to call
  /// before any send; no-ops nothing already set by `init` for tests.
  func configureContext(loggedBy: String?, familyUnitId: String?) {
    self.loggedBy = loggedBy
    self.familyUnitId = familyUnitId
  }

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
    templatesService: (any CommunicationTemplatesServicing)? = nil,
    interactionsService: (any InteractionsManaging)? = nil,
    coachesService: (any CoachesManaging)? = nil,
    loggedBy: String? = nil,
    familyUnitId: String? = nil
  ) {
    self.coach = coach
    self.schoolName = schoolName
    self.templatesService = templatesService ?? CommunicationTemplatesServiceImpl()
    self.interactionsService = interactionsService ?? InteractionsServiceImpl(supabaseManager: .shared)
    self.coachesService = coachesService ?? CoachesServiceImpl(supabaseManager: .shared)
    self.loggedBy = loggedBy
    self.familyUnitId = familyUnitId
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

  // MARK: - Send logging

  /// Log an outbound interaction for a message the in-app composer confirmed as `.sent`.
  /// Call ONLY on a confirmed send — never on `.cancelled`/`.saved`/`.failed` or the no-account
  /// fallback, so the app never records a message that wasn't actually sent.
  func logSend(_ channel: SendChannel) async {
    guard let loggedBy, let familyUnitId else {
      logger.error("Cannot log sent interaction: missing user or family context")
      errorMessage = String(localized: "Message sent, but logging it failed.")
      return
    }

    do {
      let request = InteractionCreateRequest(
        schoolId: coach.schoolId,
        coachId: coach.id,
        type: channel == .email ? .email : .text,
        direction: .outbound,
        occurredAt: Date(),
        subject: selectedTemplate?.name,
        content: filledBody.isEmpty ? nil : filledBody,
        sentiment: nil,
        loggedBy: loggedBy,
        familyUnitId: familyUnitId
      )
      _ = try await interactionsService.createInteraction(request)
      await updateLastContactDate()

      await InMemoryCache.shared.remove(forKey: ListCacheKeys.interactionsForFamily(familyUnitId: familyUnitId))
      await InMemoryCache.shared.remove(forKey: ListCacheKeys.interactionsForAthlete(userId: loggedBy))

      successMessage = channel == .email
        ? String(localized: "Logged email to Coach \(coach.fullName).")
        : String(localized: "Logged text to Coach \(coach.fullName).")
      didLogSend = true
      logger.info("Logged \(channel == .email ? "email" : "text") send to coach \(self.coach.id, privacy: .public)")
    } catch {
      logger.error("Failed to log sent interaction: \(error.localizedDescription)")
      errorMessage = String(localized: "Message sent, but logging it failed.")
    }
  }

  /// Stamp the coach's `last_contact_date` (parity with web; no DB trigger sets it).
  /// A failure here does not fail the send-log — the interaction row is the source of truth.
  private func updateLastContactDate() async {
    do {
      let iso = ISO8601DateFormatter().string(from: Date())
      _ = try await coachesService.updateCoach(id: coach.id, updates: CoachUpdateRequest(lastContactDate: iso))
    } catch {
      logger.error("Failed to update last_contact_date: \(error.localizedDescription)")
    }
  }

}
