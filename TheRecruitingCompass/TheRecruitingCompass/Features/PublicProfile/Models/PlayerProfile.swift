import Foundation

struct PlayerProfile: Codable, Equatable, Sendable {
    let id: String
    let userId: String
    let familyUnitId: String
    let hashSlug: String
    var vanitySlug: String?
    var isPublished: Bool
    var bio: String?
    var headerColor: String
    var showAcademics: Bool
    var showAthletic: Bool
    var showFilm: Bool
    var showSchools: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case familyUnitId = "family_unit_id"
        case hashSlug = "hash_slug"
        case vanitySlug = "vanity_slug"
        case isPublished = "is_published"
        case bio
        case headerColor = "header_color"
        case showAcademics = "show_academics"
        case showAthletic = "show_athletic"
        case showFilm = "show_film"
        case showSchools = "show_schools"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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
    var showAcademics: Bool?
    var showAthletic: Bool?
    var showFilm: Bool?
    var showSchools: Bool?
    var headerColor: String?
    var vanitySlug: String??

    init(
        bio: String?? = nil, isPublished: Bool? = nil,
        showAcademics: Bool? = nil, showAthletic: Bool? = nil,
        showFilm: Bool? = nil, showSchools: Bool? = nil,
        headerColor: String? = nil, vanitySlug: String?? = nil
    ) {
        self.bio = bio; self.isPublished = isPublished
        self.showAcademics = showAcademics; self.showAthletic = showAthletic
        self.showFilm = showFilm; self.showSchools = showSchools
        self.headerColor = headerColor; self.vanitySlug = vanitySlug
    }

    enum CodingKeys: String, CodingKey {
        case bio
        case isPublished = "is_published"
        case showAcademics = "show_academics"
        case showAthletic = "show_athletic"
        case showFilm = "show_film"
        case showSchools = "show_schools"
        case headerColor = "header_color"
        case vanitySlug = "vanity_slug"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        // Double-optional: outer nil = omit; inner nil = send JSON null (clears field).
        if let bio { try c.encode(bio, forKey: .bio) }
        try c.encodeIfPresent(isPublished, forKey: .isPublished)
        try c.encodeIfPresent(showAcademics, forKey: .showAcademics)
        try c.encodeIfPresent(showAthletic, forKey: .showAthletic)
        try c.encodeIfPresent(showFilm, forKey: .showFilm)
        try c.encodeIfPresent(showSchools, forKey: .showSchools)
        try c.encodeIfPresent(headerColor, forKey: .headerColor)
        if let vanitySlug { try c.encode(vanitySlug, forKey: .vanitySlug) }
    }
}
