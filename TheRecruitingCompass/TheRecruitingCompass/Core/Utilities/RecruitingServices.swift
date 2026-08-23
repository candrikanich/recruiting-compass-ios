import Foundation

/// Whether a service value is a bare ID (linked via `urlTemplate` when present)
/// or already a full URL (the value itself is the link).
enum ServiceValueKind: Sendable {
  case id
  case url
}

/// How a service's public profile link is built from its stored value.
/// - `template`: `urlTemplate.replace("{value}", value)` (Perfect Game).
/// - `url`: the stored value is itself the link (Hudl).
/// - `prepBaseball`: link built from the athlete's `prep_baseball_state` + name
///   via `RecruitingLinks.buildPrepBaseballURL` (Prep Baseball Report).
enum ServiceLinkKind: Sendable {
  case template
  case url
  case prepBaseball
}

/// Per-sport third-party recruiting services (NCSA, Hudl, Perfect Game, Prep
/// Baseball Report). Swift mirror of web `utils/services/canonical.ts`. Values
/// are flat keys stored in `user_preferences.data` (category `player`) — ZERO DB
/// migration; keys `perfect_game_id`/`prep_baseball_id` reuse the existing model
/// fields verbatim.
///
/// Every `key`, `urlTemplate`, and sport-gate MUST stay byte-identical with web
/// (see `planning/2026-08-22-phase3-registry-contract.md`, Registry B).
enum RecruitingServices {
  /// One recruiting service an athlete can list a profile on.
  struct ServiceDef: Equatable, Sendable {
    /// Flat storage key (e.g. `perfect_game_id`) — matches the PlayerDetails field.
    let key: String
    /// Display label (e.g. `Perfect Game`).
    let label: String
    /// Whether the stored value is a bare ID or a full URL.
    let valueKind: ServiceValueKind
    /// `{value}` template that turns a stored ID into a public profile link, or
    /// nil when the service has no linkable profile (signup-only) or is itself a URL.
    let urlTemplate: String?
    /// "Get your profile" signup destination.
    let signupUrl: String
    /// Input placeholder.
    let placeholder: String
    /// How the public profile link is built from the stored value (default
    /// `.template`). See `ServiceLinkKind`.
    var linkKind: ServiceLinkKind = .template
  }

  /// Build a service's public profile URL, switching on `linkKind`. Returns nil
  /// when the link cannot be formed (no template/value, empty value, or an
  /// unresolvable PBR state/name). Both platforms MUST produce byte-identical URLs.
  static func profileURL(
    for def: ServiceDef, value: String?, state: String?, name: String?
  ) -> String? {
    func nonEmpty(_ s: String?) -> String? {
      guard let trimmed = s?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty else { return nil }
      return trimmed
    }
    switch def.linkKind {
    case .template:
      guard let template = def.urlTemplate, let value = nonEmpty(value) else { return nil }
      return template.replacingOccurrences(of: "{value}", with: value)
    case .url:
      return nonEmpty(value)
    case .prepBaseball:
      return RecruitingLinks.buildPrepBaseballURL(state: state, name: name)
    }
  }

  /// Services available for a sport (case-insensitive), in registry order. Empty
  /// for nil/unknown sports — mirrors `CanonicalPositions.positions(for:)`.
  static func servicesForSport(_ sport: String?) -> [ServiceDef] {
    guard let sport, isKnownSport(sport) else { return [] }
    let key = sport.lowercased()
    return entries
      .filter { $0.sports == nil || $0.sports!.contains(key) }
      .map { $0.def }
  }

  /// Look up a single service def by its flat key (used by the public card /
  /// profile label maps). Nil for unknown keys.
  static func service(forKey key: String) -> ServiceDef? {
    entries.first { $0.def.key == key }?.def
  }

  // MARK: - Registry

  private struct Entry {
    let def: ServiceDef
    /// Lowercased sport gate; nil = all known sports.
    let sports: Set<String>?
  }

  private static let entries: [Entry] = [
    Entry(
      def: ServiceDef(key: "ncsa_id", label: String(localized: "NCSA"), valueKind: .id,
                      urlTemplate: nil, signupUrl: "https://www.ncsasports.org/",
                      placeholder: String(localized: "ID Number")),
      sports: nil
    ),
    Entry(
      def: ServiceDef(key: "hudl_url", label: String(localized: "Hudl"), valueKind: .url,
                      urlTemplate: nil, signupUrl: "https://www.hudl.com/",
                      placeholder: String(localized: "Profile URL"), linkKind: .url),
      sports: hudlSports
    ),
    Entry(
      def: ServiceDef(
        key: "perfect_game_id", label: String(localized: "Perfect Game"), valueKind: .id,
        urlTemplate: "https://www.perfectgame.org/Players/Playerprofile.aspx?ID={value}",
        signupUrl: "https://www.perfectgame.org/", placeholder: String(localized: "ID Number")
      ),
      sports: baseballSoftball
    ),
    Entry(
      def: ServiceDef(key: "prep_baseball_id", label: String(localized: "Prep Baseball Report"),
                      valueKind: .id, urlTemplate: nil,
                      signupUrl: "https://www.prepbaseballreport.com/",
                      placeholder: String(localized: "ID Number"), linkKind: .prepBaseball),
      sports: baseballSoftball
    )
  ]

  private static let baseballSoftball: Set<String> = ["baseball", "softball"]

  private static let hudlSports: Set<String> = [
    "football", "basketball", "volleyball", "soccer", "lacrosse",
    "ice hockey", "field hockey", "water polo", "wrestling"
  ]

  /// The 17 known sports (single source of truth: the position registry). An
  /// unknown sport gets no services — NCSA's "all sports" means all *known* sports.
  private static func isKnownSport(_ sport: String) -> Bool {
    CanonicalPositions.bySport.keys.contains { $0.caseInsensitiveCompare(sport) == .orderedSame }
  }
}
