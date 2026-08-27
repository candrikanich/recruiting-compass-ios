import Foundation

/// One of the six reorderable/hideable public-profile sections. Raw values are
/// the DB/API keys, byte-identical with web `ProfileSectionKey`.
enum ProfileSectionKey: String, Codable, CaseIterable, Equatable, Hashable, Sendable, Identifiable {
    case metrics, film, academics, values
    case teamHistory = "team_history"
    case awards

    var id: String { rawValue }

    /// Owner-facing label for the Section Configuration editor row, parity
    /// with web `SECTION_META`.
    var label: String {
        switch self {
        case .metrics: return String(localized: "Athletic Metrics")
        case .film: return String(localized: "Featured Videos & Highlights")
        case .academics: return String(localized: "Academic Profile")
        case .values: return String(localized: "Target Program & Values")
        case .teamHistory: return String(localized: "Team History & Coaching References")
        case .awards: return String(localized: "Honors & Awards")
        }
    }
}

/// One row of `section_config`: a section key + its visibility. Order in the
/// array IS the display order. Byte-identical with web `ProfileSection`.
struct ProfileSection: Codable, Equatable, Sendable, Identifiable {
    var key: ProfileSectionKey
    var visible: Bool
    var id: String { key.rawValue }
}

/// Mirrors web `sectionConfig.ts` `DEFAULT_SECTION_ORDER`.
enum DefaultSectionOrder {
    static let keys: [ProfileSectionKey] = [.metrics, .film, .academics, .values, .teamHistory, .awards]
}

enum CommitmentStatus: String, Codable, CaseIterable, Equatable, Sendable {
    case uncommitted, committed

    var label: String {
        switch self {
        case .uncommitted: return String(localized: "Uncommitted")
        case .committed: return String(localized: "Committed")
        }
    }
}

/// One "Awards & Athletic Honors" chip: title + optional year.
struct ProfileAward: Codable, Equatable, Sendable, Identifiable {
    var title: String
    var year: Int?
    var id: String { "\(title)-\(year.map(String.init) ?? "")" }

    enum CodingKeys: String, CodingKey {
        case title, year
    }
}

struct PlayerProfile: Codable, Equatable, Sendable {
    let id: String
    let userId: String
    let familyUnitId: String
    let hashSlug: String
    var vanitySlug: String?
    var isPublished: Bool
    var bio: String?
    var headerColor: String
    var bannerUrl: String?
    var lookingFor: String?
    var valuesTags: [String]
    var awards: [ProfileAward]
    var commitmentStatus: CommitmentStatus
    var committedSchoolId: String?
    var sectionConfig: [ProfileSection]
    // Legacy visibility columns — still accepted/returned by the API and kept
    // authoritative for `metrics`/`film`/`academics` server-side
    // (`reconcileVisibility`); `showAthletic`/`showSchools` are dead weight
    // kept only so decode never fails on an older row shape.
    var showMetrics: Bool
    var showAcademics: Bool
    var showAthletic: Bool
    var showFilm: Bool
    var showSchools: Bool
    let createdAt: String
    let updatedAt: String

    /// Explicit memberwise init — a custom `Decodable.init(from:)` suppresses the
    /// compiler-synthesized one, and tests/fixtures construct this directly.
    /// `sectionConfig` is taken as-is (no show_*-backfill resolution — callers
    /// that need that parity should go through `resolveSections` themselves).
    init(
        id: String, userId: String, familyUnitId: String, hashSlug: String,
        vanitySlug: String? = nil, isPublished: Bool, bio: String? = nil,
        headerColor: String, bannerUrl: String? = nil, lookingFor: String? = nil,
        valuesTags: [String] = [], awards: [ProfileAward] = [],
        commitmentStatus: CommitmentStatus = .uncommitted, committedSchoolId: String? = nil,
        sectionConfig: [ProfileSection] = DefaultSectionOrder.keys.map { ProfileSection(key: $0, visible: true) },
        showMetrics: Bool = true, showAcademics: Bool = true, showAthletic: Bool = true,
        showFilm: Bool = true, showSchools: Bool = true,
        createdAt: String, updatedAt: String
    ) {
        self.id = id
        self.userId = userId
        self.familyUnitId = familyUnitId
        self.hashSlug = hashSlug
        self.vanitySlug = vanitySlug
        self.isPublished = isPublished
        self.bio = bio
        self.headerColor = headerColor
        self.bannerUrl = bannerUrl
        self.lookingFor = lookingFor
        self.valuesTags = valuesTags
        self.awards = awards
        self.commitmentStatus = commitmentStatus
        self.committedSchoolId = committedSchoolId
        self.sectionConfig = sectionConfig
        self.showMetrics = showMetrics
        self.showAcademics = showAcademics
        self.showAthletic = showAthletic
        self.showFilm = showFilm
        self.showSchools = showSchools
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case familyUnitId = "family_unit_id"
        case hashSlug = "hash_slug"
        case vanitySlug = "vanity_slug"
        case isPublished = "is_published"
        case bio
        case headerColor = "header_color"
        case bannerUrl = "banner_url"
        case lookingFor = "looking_for"
        case valuesTags = "values_tags"
        case awards
        case commitmentStatus = "commitment_status"
        case committedSchoolId = "committed_school_id"
        case sectionConfig = "section_config"
        case showMetrics = "show_metrics"
        case showAcademics = "show_academics"
        case showAthletic = "show_athletic"
        case showFilm = "show_film"
        case showSchools = "show_schools"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = try c.decode(String.self, forKey: .userId)
        familyUnitId = try c.decode(String.self, forKey: .familyUnitId)
        hashSlug = try c.decode(String.self, forKey: .hashSlug)
        vanitySlug = try c.decodeIfPresent(String.self, forKey: .vanitySlug)
        isPublished = try c.decode(Bool.self, forKey: .isPublished)
        bio = try c.decodeIfPresent(String.self, forKey: .bio)
        headerColor = try c.decodeIfPresent(String.self, forKey: .headerColor) ?? HeaderColor.slate.rawValue
        bannerUrl = try c.decodeIfPresent(String.self, forKey: .bannerUrl)
        lookingFor = try c.decodeIfPresent(String.self, forKey: .lookingFor)
        valuesTags = try c.decodeIfPresent([String].self, forKey: .valuesTags) ?? []
        awards = try c.decodeIfPresent([ProfileAward].self, forKey: .awards) ?? []
        commitmentStatus = try c.decodeIfPresent(CommitmentStatus.self, forKey: .commitmentStatus) ?? .uncommitted
        committedSchoolId = try c.decodeIfPresent(String.self, forKey: .committedSchoolId)
        showMetrics = try c.decodeIfPresent(Bool.self, forKey: .showMetrics) ?? false
        showAcademics = try c.decodeIfPresent(Bool.self, forKey: .showAcademics) ?? false
        showAthletic = try c.decodeIfPresent(Bool.self, forKey: .showAthletic) ?? false
        showFilm = try c.decodeIfPresent(Bool.self, forKey: .showFilm) ?? false
        showSchools = try c.decodeIfPresent(Bool.self, forKey: .showSchools) ?? false
        let rawSections = try c.decodeIfPresent([ProfileSection].self, forKey: .sectionConfig) ?? []
        sectionConfig = Self.resolveSections(
            raw: rawSections, showMetrics: showMetrics, showFilm: showFilm, showAcademics: showAcademics
        )
        createdAt = try c.decode(String.self, forKey: .createdAt)
        updatedAt = try c.decode(String.self, forKey: .updatedAt)
    }

    /// Parity with web `resolveSections`/`backfillSectionConfig`: an empty/
    /// missing `section_config` backfills from the legacy show_* flags
    /// (metrics/film/academics) with values/team_history/awards defaulting
    /// visible; a non-empty stored config still has metrics/film/academics
    /// overridden by the legacy flags (server-authoritative).
    static func resolveSections(
        raw: [ProfileSection], showMetrics: Bool, showFilm: Bool, showAcademics: Bool
    ) -> [ProfileSection] {
        let overrides: [ProfileSectionKey: Bool] = [
            .metrics: showMetrics, .film: showFilm, .academics: showAcademics
        ]
        var base: [ProfileSection]
        if raw.isEmpty {
            base = DefaultSectionOrder.keys.map { key in
                let defaultVisible = overrides[key] ?? true
                return ProfileSection(key: key, visible: defaultVisible)
            }
        } else {
            var seen = Set<ProfileSectionKey>()
            base = raw.filter { seen.insert($0.key).inserted }
            for key in DefaultSectionOrder.keys where !seen.contains(key) {
                base.append(ProfileSection(key: key, visible: false))
            }
        }
        return base.map { section in
            guard let override = overrides[section.key] else { return section }
            return ProfileSection(key: section.key, visible: override)
        }
    }
}

struct ProfileTrackingLink: Codable, Equatable, Sendable {
    let id: String
    let profileId: String
    let coachId: String
    let refToken: String
    let viewCount: Int
    let lastViewedAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case coachId = "coach_id"
        case refToken = "ref_token"
        case viewCount = "view_count"
        case lastViewedAt = "last_viewed_at"
        case createdAt = "created_at"
    }
}

/// PUT /api/player/profile body — all fields optional; only non-nil fields serialize.
struct UpdateProfilePayload: Encodable, Equatable {
    var bio: String??
    var isPublished: Bool?
    var headerColor: String?
    var vanitySlug: String??
    var bannerUrl: String??
    var lookingFor: String??
    var valuesTags: [String]?
    var awards: [ProfileAward]?
    var commitmentStatus: CommitmentStatus?
    var committedSchoolId: String??
    var sectionConfig: [ProfileSection]?

    init(
        bio: String?? = nil, isPublished: Bool? = nil,
        headerColor: String? = nil, vanitySlug: String?? = nil,
        bannerUrl: String?? = nil, lookingFor: String?? = nil,
        valuesTags: [String]? = nil, awards: [ProfileAward]? = nil,
        commitmentStatus: CommitmentStatus? = nil, committedSchoolId: String?? = nil,
        sectionConfig: [ProfileSection]? = nil
    ) {
        self.bio = bio
        self.isPublished = isPublished
        self.headerColor = headerColor
        self.vanitySlug = vanitySlug
        self.bannerUrl = bannerUrl
        self.lookingFor = lookingFor
        self.valuesTags = valuesTags
        self.awards = awards
        self.commitmentStatus = commitmentStatus
        self.committedSchoolId = committedSchoolId
        self.sectionConfig = sectionConfig
    }

    enum CodingKeys: String, CodingKey {
        case bio
        case isPublished = "is_published"
        case headerColor = "header_color"
        case vanitySlug = "vanity_slug"
        case bannerUrl = "banner_url"
        case lookingFor = "looking_for"
        case valuesTags = "values_tags"
        case awards
        case commitmentStatus = "commitment_status"
        case committedSchoolId = "committed_school_id"
        case sectionConfig = "section_config"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Double-optional: outer nil = omit; inner nil = send JSON null (clears field).
        if let bio { try container.encode(bio, forKey: .bio) }
        try container.encodeIfPresent(isPublished, forKey: .isPublished)
        try container.encodeIfPresent(headerColor, forKey: .headerColor)
        if let vanitySlug { try container.encode(vanitySlug, forKey: .vanitySlug) }
        if let bannerUrl { try container.encode(bannerUrl, forKey: .bannerUrl) }
        if let lookingFor { try container.encode(lookingFor, forKey: .lookingFor) }
        try container.encodeIfPresent(valuesTags, forKey: .valuesTags)
        try container.encodeIfPresent(awards, forKey: .awards)
        try container.encodeIfPresent(commitmentStatus, forKey: .commitmentStatus)
        if let committedSchoolId { try container.encode(committedSchoolId, forKey: .committedSchoolId) }
        try container.encodeIfPresent(sectionConfig, forKey: .sectionConfig)
    }
}
