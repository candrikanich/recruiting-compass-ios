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
  private let videoLinksService: any VideoLinksManaging
  private let templateVariablesService: any TemplateVariablesServicing
  private let contextService: any TemplateContextProviding
  private let schoolsService: any SchoolsManaging
  private let contactWindowService: any ContactWindowServicing
  private let athleteMessagesService: any AthleteMessagesServicing
  private var loggedBy: String?
  private var familyUnitId: String?
  private var athleteUserId: String?
  private var accessToken: String?

  // MARK: - Phase 3 send guardrails

  enum GuardrailChannel { case email, text }
  /// Pre-send guardrail message (block reason or two-step warning); nil when clear.
  var sendWarning: String?
  /// Armed after a two-step warning so the next send tap proceeds.
  private var sendArmed = false

  // MARK: - Phase 2a resolution engine

  /// The global variable registry (loaded once via `loadResolverInputs`).
  private(set) var registry: [TemplateVariableDef] = []
  /// Gathered athlete/coach/school context (built via `loadResolverInputs`).
  private(set) var resolvedContext: ResolverContext?
  /// Global contact-window rules (loaded once via `loadResolverInputs`, fail-open []).
  private(set) var contactWindowRules: [ContactWindowRule] = []
  /// Per-message authored values (empty in 2a; the variables panel writes here in 2b).
  var authoredValues: [String: String] = [:]

  /// User overrides of the resolved subject/body — nil until edited, then they drive
  /// preview + send. Cleared on every `selectTemplate` (fresh template → fresh text).
  var editedSubject: String?
  var editedBody: String?
  /// SMS body cap (parity with web); `.message` sends are gated over this.
  static let textLimit = 160

  /// Cached film-link substitution values, populated by `loadVideoLinks()`. Kept as stored
  /// properties (not fetched inline in `substitutionValues`) since that computed property
  /// must stay synchronous for `filledBody`/`mailtoURL`/`smsURL` call sites.
  private var filmLinksValue: String = ""
  private var primaryFilmLinkValue: String = ""

  /// Supply the signed-in user + family context resolved from the environment at the
  /// presentation site (the sheet call sites don't inject the ViewModel). Safe to call
  /// before any send; no-ops nothing already set by `init` for tests.
  func configureContext(loggedBy: String?, familyUnitId: String?,
                        athleteUserId: String? = nil, accessToken: String? = nil) {
    self.loggedBy = loggedBy
    self.familyUnitId = familyUnitId
    self.athleteUserId = athleteUserId
    self.accessToken = accessToken
  }

  /// Pre-send guardrails (1:1 with web `passesSendGuardrails`). Returns true when the send may
  /// proceed. Fails OPEN — no athlete or any lookup error never blocks a legit send.
  func evaluateGuardrails(_ channel: GuardrailChannel) async -> Bool {
    guard let athleteUserId else { return true }
    guard let check = try? await athleteMessagesService.checkSend(
      SendCheckInput(athleteUserId: athleteUserId, schoolId: coach.schoolId,
                     programNote: authoredValues["programNote"]),
      accessToken: accessToken) else {
      sendWarning = nil
      return true
    }
    if check.programNoteReused {
      sendWarning = String(localized: """
        Your reason for reaching out was already sent to another program. Coaches notice \
        reused messages — make it specific to this program before sending.
        """)
      return false
    }
    if !sendArmed && (check.recentContact || check.messageCountToSchool >= 2) {
      sendWarning = check.recentContact
        ? String(localized: """
          You last messaged this program \(check.daysSinceLastContact ?? 0) day(s) ago. \
          Tap Send again to send anyway.
          """)
        : String(localized: """
          You've already sent \(check.messageCountToSchool) messages here — consider adding \
          more programs. Tap Send again to send anyway.
          """)
      sendArmed = true
      return false
    }
    sendWarning = nil
    return true
  }

  /// Best-effort API send log on a confirmed send (in addition to the interaction log).
  func logMessageSend(_ channel: GuardrailChannel) async {
    guard let athleteUserId else { return }
    try? await athleteMessagesService.logSend(LogMessageInput(
      athleteUserId: athleteUserId, schoolId: coach.schoolId, coachId: coach.id,
      templateSlug: selectedTemplate?.slug, channel: channel == .email ? "email" : "text",
      programNote: authoredValues["programNote"], updateHook: authoredValues["updateHook"],
      subject: channel == .email ? cleanSubject : nil, body: cleanBody),
      accessToken: accessToken)
  }

  /// Loads the athlete's video links (if `athleteUserId` was supplied via `configureContext`)
  /// so `{{film_links}}`/`{{primary_film_link}}` can be filled in `filledBody`. Best-effort:
  /// leaves the values empty (falling back to `[Variable Name]` placeholders) on failure.
  func loadVideoLinks() async {
    guard let athleteUserId else { return }
    do {
      let links = try await videoLinksService.fetchVideoLinks(userId: athleteUserId)
      primaryFilmLinkValue = (links.first { $0.healthStatus == .healthy } ?? links.first)?.url ?? ""
      filmLinksValue = links
        .map { "\($0.title ?? $0.url) (\($0.platform.displayName.uppercased())): \($0.url)" }
        .joined(separator: "\n")
    } catch {
      logger.error("Failed to load video links for film-link template variables: \(error.localizedDescription)")
    }
  }

  /// Load the variable registry + gather athlete/coach/school context once (best-effort).
  func loadResolverInputs() async {
    if registry.isEmpty {
      registry = (try? await templateVariablesService.fetchRegistry()) ?? []
    }
    var school: School?
    if let familyUnitId {
      school = try? await schoolsService.fetchSchool(id: coach.schoolId, familyUnitId: familyUnitId)
    }
    resolvedContext = await contextService.buildContext(
      coach: coach, school: school, athleteUserId: athleteUserId,
      authored: authoredValues, now: Date())
    if contactWindowRules.isEmpty {
      contactWindowRules = (try? await contactWindowService.fetchRules()) ?? []
    }
  }

  /// Current pre/open window state for this athlete+school (fail-open `.open`).
  var contactWindowState: ContactWindowState {
    guard let ctx = resolvedContext else { return .open }
    return ContactWindow.evaluate(rules: contactWindowRules, input: ContactWindowInput(
      sport: ctx.derived["sport"],
      division: ctx.tables["schools"]?["division"],
      gradYear: ctx.tables["users"]?["graduation_year"].flatMap(Int.init),
      today: Date())).state
  }

  private func windowFiltered(_ list: [CommunicationTemplate]) -> [CommunicationTemplate] {
    ContactWindow.filterByWindow(list, state: contactWindowState,
      group: { "\($0.type.rawValue):\($0.stage ?? "")" }, window: { $0.contactWindow })
  }

  private func resolvedValues() -> [String: String] {
    guard var ctx = resolvedContext else { return [:] }
    ctx.authored = authoredValues
    return TemplateResolver.buildValues(registry: registry, context: ctx)
  }

  /// Selected template subject with registry variables filled (empty when none/no subject).
  var resolvedSubject: String {
    guard let subject = selectedTemplate?.subject, !subject.isEmpty else { return "" }
    return TemplateResolver.render(subject, values: resolvedValues())
  }

  /// Selected template body with registry variables filled.
  var resolvedBody: String {
    guard let body = selectedTemplate?.body else { return "" }
    return TemplateResolver.render(body, values: resolvedValues())
  }

  /// Preview/send subject+body after applying any user edit over the resolver output.
  var effectiveSubject: String { editedSubject ?? resolvedSubject }
  var effectiveBody: String { editedBody ?? resolvedBody }

  /// Registry keys marked required — the ONLY ones that block send when unresolved.
  /// Optional unresolved tokens are stripped by `renderClean`, not gated.
  private var requiredKeys: Set<String> {
    Set(registry.filter { $0.isRequiredDefault }.map { $0.key })
  }

  /// Subject/body with optional-empty tokens stripped (and label-only lines dropped);
  /// required unresolved tokens remain so they show in preview and gate the send.
  var cleanSubject: String {
    TemplateResolver.renderClean(effectiveSubject, values: resolvedValues(), requiredKeys: requiredKeys)
  }
  var cleanBody: String {
    TemplateResolver.renderClean(effectiveBody, values: resolvedValues(), requiredKeys: requiredKeys)
  }

  /// True when the template leans on the athlete's stats (`{{metrics}}`/`{{carryingTool}}`)
  /// but none resolve yet — surfaces an "add a metric" nudge in the compose flow.
  var suggestsAddingMetrics: Bool {
    referencedVariables.contains {
      ($0.key == "metrics" || $0.key == "carryingTool") && !$0.isResolved
    }
  }

  /// The selected template's referenced variables (authored/resolved-tagged) for the panel.
  var referencedVariables: [ReferencedVariable] {
    guard let template = selectedTemplate else { return [] }
    return TemplateVariableExtractor.referenced(
      subject: template.subject, body: template.body,
      registry: registry, resolvedValues: resolvedValues())
  }

  /// Two-way binding into `authoredValues` for a panel input.
  func authoredBinding(for key: String) -> Binding<String> {
    Binding(get: { [weak self] in self?.authoredValues[key] ?? "" },
            set: { [weak self] in self?.authoredValues[key] = $0 })
  }

  /// True when a text (`.message`) template's SENT body exceeds the SMS cap.
  var textBodyOverLimit: Bool {
    selectedTemplate?.type == .message && cleanBody.count > Self.textLimit
  }

  /// The body used for send/preview: cleaned resolver output (optional-empty tokens/lines
  /// removed) when the registry is active, else the legacy 4-var fill.
  var messageBody: String {
    registry.isEmpty ? filledBody : cleanBody
  }

  /// REQUIRED tokens still unresolved in the cleaned subject+body (deduped). After
  /// `renderClean`, optional tokens are already stripped, so only required ones can remain.
  var unresolvedKeys: [String] {
    guard !registry.isEmpty, selectedTemplate != nil else { return [] }
    return TemplateResolver.findUnresolved(cleanSubject + "\n" + cleanBody)
  }

  /// True when required tokens remain or a text body is over the cap — blocks send.
  var isSendBlocked: Bool { !unresolvedKeys.isEmpty || textBodyOverLimit }

  var recipientLine: String {
    "\(coach.fullName) – \(coach.role.displayName)"
  }

  var emailTemplates: [CommunicationTemplate] {
    windowFiltered(templates.filter { $0.type == .email })
  }

  var textTemplates: [CommunicationTemplate] {
    windowFiltered(templates.filter { $0.type == .message })
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
    result["film_links"] = filmLinksValue
    result["primary_film_link"] = primaryFilmLinkValue
    return result
  }

  init(
    coach: Coach,
    schoolName: String? = nil,
    templatesService: (any CommunicationTemplatesServicing)? = nil,
    interactionsService: (any InteractionsManaging)? = nil,
    coachesService: (any CoachesManaging)? = nil,
    videoLinksService: (any VideoLinksManaging)? = nil,
    templateVariablesService: (any TemplateVariablesServicing)? = nil,
    contextService: (any TemplateContextProviding)? = nil,
    schoolsService: (any SchoolsManaging)? = nil,
    contactWindowService: (any ContactWindowServicing)? = nil,
    athleteMessagesService: (any AthleteMessagesServicing)? = nil,
    loggedBy: String? = nil,
    familyUnitId: String? = nil
  ) {
    self.coach = coach
    self.schoolName = schoolName
    self.templatesService = templatesService ?? CommunicationTemplatesServiceImpl()
    self.interactionsService = interactionsService ?? InteractionsServiceImpl(supabaseManager: .shared)
    self.coachesService = coachesService ?? CoachesServiceImpl(supabaseManager: .shared)
    self.videoLinksService = videoLinksService ?? VideoLinksServiceImpl()
    self.templateVariablesService = templateVariablesService ?? TemplateVariablesServiceImpl()
    self.contextService = contextService ?? TemplateContextService()
    self.schoolsService = schoolsService ?? SchoolsServiceImpl(supabaseManager: .shared)
    self.contactWindowService = contactWindowService ?? ContactWindowServiceImpl()
    self.athleteMessagesService = athleteMessagesService ?? AthleteMessagesServiceImpl()
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
    editedSubject = nil
    editedBody = nil
    sendWarning = nil
    sendArmed = false
  }

  /// Maximum body length for mailto/sms URLs. Launch Services fails (-10814) when URLs exceed system limits.
  private static let maxURLBodyLength = 1500

  /// URL to open Mail with pre-filled recipient and optional body. Returns nil if coach has no email.
  /// Body is truncated if it exceeds system URL length limits (Launch Services -10814).
  func mailtoURL() -> URL? {
    guard let email = coach.email?.trimmingCharacters(in: .whitespaces), !email.isEmpty else { return nil }
    var components = URLComponents(string: "mailto:\(email)")
    if !messageBody.isEmpty {
      let body = truncateBodyForURL(messageBody)
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
    if !messageBody.isEmpty {
      let body = truncateBodyForURL(messageBody)
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
        content: messageBody.isEmpty ? nil : messageBody,
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
