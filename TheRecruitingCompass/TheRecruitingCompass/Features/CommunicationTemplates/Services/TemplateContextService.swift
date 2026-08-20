import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "TemplateContextService"
)

protocol TemplateContextProviding: Sendable {
  func buildContext(coach: Coach, school: School?, athleteUserId: String?,
                    authored: [String: String], now: Date) async -> ResolverContext
}

struct TemplateContextService: TemplateContextProviding {
  private let supabaseManager: SupabaseManager
  private let videoLinksService: any VideoLinksManaging

  init(supabaseManager: SupabaseManager = .shared,
       videoLinksService: (any VideoLinksManaging)? = nil) {
    self.supabaseManager = supabaseManager
    self.videoLinksService = videoLinksService ?? VideoLinksServiceImpl()
  }

  func buildContext(coach: Coach, school: School?, athleteUserId: String?,
                    authored: [String: String], now: Date) async -> ResolverContext {
    // Selected coach → coaches table dict (typed model → known cols).
    var coachTable: [String: String] = ["first_name": coach.firstName, "last_name": coach.lastName]
    if let role = coach.position { coachTable["role"] = role }

    var schoolTable: [String: String] = [:]
    if let school {
      schoolTable["name"] = school.name
      if let v = school.division { schoolTable["division"] = v }
      if let v = school.conference { schoolTable["conference"] = v }
      if let v = school.city { schoolTable["city"] = v }
      if let v = school.state { schoolTable["state"] = v }
      if let v = school.twitterHandle { schoolTable["twitter_handle"] = v }
      // Backs {{questionnaireNote}} — the resolver reads the string "true"/"false".
      schoolTable["questionnaire_completed"] = school.questionnaireCompleted ? "true" : "false"
    }

    // Athlete-owned data (all best-effort; any failure → empty).
    var usersTable: [String: String] = [:]
    var prefs: [String: String] = [:]
    var locationPrefs: [String: String] = [:]
    var positions: [String] = []
    var metrics: [TemplateMetricRow] = []
    var events: [EventLite] = []
    var gradYear: Int?
    var profileSlug: String?
    var transcriptURL: String?
    var videoPrimaryURL: String?

    if let uid = athleteUserId {
      usersTable = (try? await fetchRowDict(table: "users", idColumn: "id", id: uid)) ?? [:]
      gradYear = usersTable["graduation_year"].flatMap { Int($0) }
      let fetchedPrefs = (try? await fetchPlayerPrefs(userId: uid)) ?? (scalars: [:], positions: [])
      prefs = fetchedPrefs.scalars
      if let phone = prefs["phone"] { prefs["phone"] = TemplateComputed.usPhone(phone) }
      positions = fetchedPrefs.positions
      locationPrefs = (try? await fetchCategoryPrefs(userId: uid, category: "location")) ?? [:]
      metrics = (try? await fetchMetrics(userId: uid)) ?? []
      events = (try? await fetchEvents(userId: uid)) ?? []
      profileSlug = try? await fetchProfileSlug(userId: uid)
      transcriptURL = try? await fetchTranscriptURL(userId: uid)
      if let links = try? await videoLinksService.fetchVideoLinks(userId: uid) {
        videoPrimaryURL = (links.first { $0.healthStatus == .healthy } ?? links.first)?.url
      }
    }

    let derived = TemplateContextBuilder.buildDerived(
      prefs: prefs, positions: positions, metrics: metrics, events: events, profileSlug: profileSlug,
      transcriptURL: transcriptURL, videoPrimaryURL: videoPrimaryURL, gradYear: gradYear, now: now)

    return ResolverContext(
      tables: ["users": usersTable, "coaches": coachTable, "schools": schoolTable, "events": [:]],
      prefs: prefs, locationPrefs: locationPrefs, authored: authored, derived: derived,
      metrics: metrics, events: events, now: now)
  }

  // MARK: - Raw fetch helpers

  /// Fetch one row as [col: scalarString], omitting null/empty/array/object values.
  private func fetchRowDict(table: String, idColumn: String, id: String) async throws -> [String: String] {
    let row: JSONObject = try await supabaseManager.client
      .from(table).select("*").eq(idColumn, value: id).single().execute().value
    return row.reduce(into: [:]) { acc, kv in
      if let scalar = Self.scalarString(kv.value) { acc[kv.key] = scalar }
    }
  }

  /// Flattened scalar prefs plus the ordered `positions[]` array (dropped by the
  /// scalar flatten, but needed for coach-facing "3B/SS" position rendering).
  private func fetchPlayerPrefs(userId: String) async throws -> (scalars: [String: String], positions: [String]) {
    struct PrefRow: Decodable { let data: JSONObject }
    let rows: [PrefRow] = try await supabaseManager.client
      .from("user_preferences").select("data")
      .eq("user_id", value: userId).eq("category", value: "player")
      .execute().value
    guard let data = rows.first?.data else { return ([:], []) }
    let scalars = data.reduce(into: [String: String]()) { acc, kv in
      if let scalar = Self.scalarString(kv.value) { acc[kv.key] = scalar }
    }
    var positions: [String] = []
    if case let .array(items)? = data["positions"] {
      positions = items.compactMap { item in
        if case let .string(s) = item {
          let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
          return t.isEmpty ? nil : t
        }
        return nil
      }
    }
    return (scalars, positions)
  }

  /// Flattened scalar prefs for any single category (e.g. "location" → home city/state/zip).
  private func fetchCategoryPrefs(userId: String, category: String) async throws -> [String: String] {
    struct PrefRow: Decodable { let data: JSONObject }
    let rows: [PrefRow] = try await supabaseManager.client
      .from("user_preferences").select("data")
      .eq("user_id", value: userId).eq("category", value: category)
      .execute().value
    guard let data = rows.first?.data else { return [:] }
    return data.reduce(into: [String: String]()) { acc, kv in
      if let scalar = Self.scalarString(kv.value) { acc[kv.key] = scalar }
    }
  }

  private func fetchMetrics(userId: String) async throws -> [TemplateMetricRow] {
    try await supabaseManager.client
      .from("performance_metrics").select("*").eq("user_id", value: userId).execute().value
  }

  private func fetchEvents(userId: String) async throws -> [EventLite] {
    struct Row: Decodable {
      let name: String?
      let startDate: String?
      let endDate: String?
      let location: String?
      let city: String?
      let state: String?
      let url: String?
      enum CodingKeys: String, CodingKey {
        case name, location, city, state, url
        case startDate = "start_date"
        case endDate = "end_date"
      }
    }
    let rows: [Row] = try await supabaseManager.client
      .from("events").select("name, start_date, end_date, location, city, state, url")
      .eq("user_id", value: userId).execute().value
    return rows.map { EventLite(name: $0.name, startDate: $0.startDate, endDate: $0.endDate,
                                location: $0.location, city: $0.city, state: $0.state, url: $0.url) }
  }

  private func fetchProfileSlug(userId: String) async throws -> String? {
    struct Row: Decodable {
      let vanitySlug: String?
      let hashSlug: String?
      enum CodingKeys: String, CodingKey {
        case vanitySlug = "vanity_slug"
        case hashSlug = "hash_slug"
      }
    }
    let rows: [Row] = try await supabaseManager.client
      .from("player_profiles").select("vanity_slug, hash_slug")
      .eq("user_id", value: userId).limit(1).execute().value
    guard let r = rows.first else { return nil }
    return r.vanitySlug ?? r.hashSlug
  }

  private func fetchTranscriptURL(userId: String) async throws -> String? {
    struct Row: Decodable {
      let fileUrl: String?
      enum CodingKeys: String, CodingKey { case fileUrl = "file_url" }
    }
    let rows: [Row] = try await supabaseManager.client
      .from("documents").select("file_url")
      .eq("user_id", value: userId).eq("type", value: "transcript")
      .order("created_at", ascending: false).limit(1).execute().value
    return rows.first?.fileUrl
  }

  /// AnyJSON scalar → trimmed string, else nil (arrays/objects/null omitted).
  static func scalarString(_ json: AnyJSON) -> String? {
    switch json {
    case .string(let s):
      let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
      return t.isEmpty ? nil : t
    case .integer(let i): return String(i)
    case .double(let d): return d == d.rounded() ? String(Int(d)) : String(d)
    case .bool(let b): return b ? "true" : "false"
    case .null, .array, .object: return nil
    }
  }
}
