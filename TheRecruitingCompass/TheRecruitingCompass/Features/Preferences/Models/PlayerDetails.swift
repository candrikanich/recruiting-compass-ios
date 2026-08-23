import Foundation

/// One travel/club team an athlete has played for. These keys are plain
/// (year/name/coach) because they are object keys INSIDE the `travel_teams`
/// JSON array — only top-level prefs keys are snake_cased.
struct TravelTeam: Codable, Equatable, Sendable {
  var year: Int?
  var name: String?
  var coach: String?
}

struct PlayerDetails: Codable, Equatable, Sendable {
  // Basic Info
  var graduationYear: Int?
  var highSchool: String?
  var clubTeam: String?

  // Athletic Profile
  var primarySport: String?
  var primaryPosition: String?
  var positions: [String]?

  // Physical Stats
  var bats: String? // "L" | "R" | "S"
  var throws_: String? // "L" | "R"
  var heightInches: Int?
  var weightLbs: Int?

  // Per-sport laterality attributes (registry-driven — see AthleteAttributes).
  // Each stores a bare option token (e.g. "L"/"R"/"S"). Empty/nil = unset.
  var shootingHand: String?     // Basketball
  var dominantFoot: String?     // Soccer ("L" | "R" | "Both")
  var hittingHand: String?      // Volleyball
  var racketHand: String?       // Tennis
  var backhandStyle: String?    // Tennis ("one" | "two")
  var golfHandedness: String?   // Golf
  var dominantHand: String?     // Lacrosse
  var shoots: String?           // Ice Hockey
  var catches: String?          // Ice Hockey (Goalie)
  var wpDominantHand: String?   // Water Polo
  var rowingSide: String?       // Rowing ("port" | "starboard" | "both" | "cox")
  var rowingDiscipline: String? // Rowing ("sweep" | "scull" | "both")
  var throwingHand: String?     // Football (Quarterback)
  var kickingFoot: String?      // Football (Kicker/Punter)

  // Academics
  var gpa: Double? // 0.0-5.0
  var satScore: Int? // 400-1600
  var actScore: Int? // 1-36
  var coreCourses: [String]? // AP/honors/notable courses (max 20)
  var intendedMajor: String? // backs template {{intendedMajor}}

  // External IDs / recruiting services (registry-driven — see RecruitingServices).
  var ncaaId: String? // NCAA Eligibility Center (not a registry service)
  var perfectGameId: String?
  var prepBaseballId: String?
  // 2-letter state code (or full state name) the athlete's PBR profile lives
  // under — PBR files profiles by state. Drives the slug-based profile link.
  var prepBaseballState: String?
  var ncsaId: String?  // NCSA (all sports)
  var hudlUrl: String? // Hudl (full profile URL)
  // Services v2 (registry-driven — see RecruitingServices). id-kind store a bare
  // ID; url-kind (*_url) store the full profile URL, like Hudl.
  var athleticNetId: String?      // Athletic.net (Track & Field, Cross Country)
  var milesplitUrl: String?       // MileSplit (Track & Field, Cross Country)
  var swimcloudId: String?        // SwimCloud (Swimming)
  var utrId: String?              // Universal Tennis / UTR (Tennis)
  var tennisRecruitingId: String? // Tennis Recruiting Network (Tennis)
  var eliteProspectsId: String?   // Elite Prospects (Ice Hockey)
  var sportsrecruitsId: String?   // SportsRecruits (Soccer, Lacrosse, Volleyball, Field Hockey)
  var concept2Id: String?         // Concept2 Logbook (Rowing)
  var on3Url: String?             // On3 (Football, Basketball)
  var sports247Url: String?       // 247Sports (Football, Basketball)

  // Social Media
  var twitterHandle: String?
  var instagramHandle: String?
  var tiktokHandle: String?
  var facebookUrl: String?

  // Contact
  var phone: String?
  var email: String?
  var allowSharePhone: Bool?
  var allowShareEmail: Bool?

  // College Preferences (fit analysis) — canonical enums shared with web:
  // campusSizePreference: "small" | "medium" | "large"
  // costSensitivity: "high" | "medium" | "low"
  var campusSizePreference: String?
  var costSensitivity: String?

  // Demographics
  var gender: String? // "male" | "female" | "other" | "prefer_not_to_say"

  // School Info
  var schoolName: String?
  var schoolAddress: String?
  var schoolCity: String?
  var schoolState: String?

  // High School Teams
  var ninthGradeTeam: String?
  var ninthGradeCoach: String?
  var tenthGradeTeam: String?
  var tenthGradeCoach: String?
  var eleventhGradeTeam: String?
  var eleventhGradeCoach: String?
  var twelfthGradeTeam: String?
  var twelfthGradeCoach: String?

  // Travel Team — legacy scalars mirror the most-recent team; kept because the
  // coach-outreach template resolver and profile edit-history read them.
  var travelTeamYear: Int?
  var travelTeamName: String?
  var travelTeamCoach: String?
  // Full repeatable list; scalars above always mirror the highest-year row.
  var travelTeams: [TravelTeam]?

  static var `default`: PlayerDetails {
    PlayerDetails()
  }

  /// Flat storage key → the optional-String field backing it. Lets the
  /// registry-driven AthleticsTab read/write a dynamic set of attribute/service
  /// fields by their `user_preferences.data` key while staying fully type-safe.
  /// Keys match `AthleteAttributes` / `RecruitingServices`.
  static let stringFieldKeyPaths: [String: WritableKeyPath<PlayerDetails, String?>] = [
    // Attributes
    "bats": \.bats,
    "throws": \.throws_,
    "shooting_hand": \.shootingHand,
    "dominant_foot": \.dominantFoot,
    "hitting_hand": \.hittingHand,
    "racket_hand": \.racketHand,
    "backhand_style": \.backhandStyle,
    "golf_handedness": \.golfHandedness,
    "dominant_hand": \.dominantHand,
    "shoots": \.shoots,
    "catches": \.catches,
    "wp_dominant_hand": \.wpDominantHand,
    "rowing_side": \.rowingSide,
    "rowing_discipline": \.rowingDiscipline,
    "throwing_hand": \.throwingHand,
    "kicking_foot": \.kickingFoot,
    // Services
    "ncsa_id": \.ncsaId,
    "hudl_url": \.hudlUrl,
    "perfect_game_id": \.perfectGameId,
    "prep_baseball_id": \.prepBaseballId,
    "prep_baseball_state": \.prepBaseballState,
    // Services v2
    "athletic_net_id": \.athleticNetId,
    "milesplit_url": \.milesplitUrl,
    "swimcloud_id": \.swimcloudId,
    "utr_id": \.utrId,
    "tennis_recruiting_id": \.tennisRecruitingId,
    "elite_prospects_id": \.eliteProspectsId,
    "sportsrecruits_id": \.sportsrecruitsId,
    "concept2_id": \.concept2Id,
    "on3_url": \.on3Url,
    "sports247_url": \.sports247Url
  ]

  /// Type-safe read/write of a flat attribute/service field by its storage key.
  /// Unknown keys read `nil` and ignore writes.
  subscript(attributeKey key: String) -> String? {
    get {
      guard let keyPath = Self.stringFieldKeyPaths[key] else { return nil }
      return self[keyPath: keyPath]
    }
    set {
      guard let keyPath = Self.stringFieldKeyPaths[key] else { return }
      self[keyPath: keyPath] = newValue
    }
  }

  /// Weighted profile completeness (0.0–1.0). Canonical formula shared with the web
  /// app — see `planning/2026-08-09-profile-completeness-canonical-spec.md`.
  ///
  /// `hasHighlightVideo` and `hasHomeLocation` live outside the player-prefs blob
  /// (the `video_links` table and the location store), so the caller fetches them
  /// and passes them in — keeping this function pure and unit-testable.
  func completenessScore(hasHighlightVideo: Bool, hasHomeLocation: Bool) -> Double {
    func filled(_ s: String?) -> Bool {
      !(s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var score = 0.0
    if graduationYear != nil { score += 0.10 }
    if filled(primarySport) { score += 0.10 }
    if filled(primaryPosition) { score += 0.10 }
    if hasHomeLocation { score += 0.10 }
    if gpa != nil { score += 0.15 }
    if satScore != nil || actScore != nil { score += 0.10 }
    if hasHighlightVideo { score += 0.15 }
    if heightInches != nil { score += 0.05 }
    if weightLbs != nil { score += 0.05 }
    if filled(phone) { score += 0.10 }
    return score
  }

  /// True when all core profile fields are filled. Drives the Settings "Complete" badge.
  /// Video is excluded — it lives in its own Settings row and is not required for the badge.
  func isComplete(hasHomeLocation: Bool) -> Bool {
    completenessScore(hasHighlightVideo: false, hasHomeLocation: hasHomeLocation) >= 0.85
  }

  enum CodingKeys: String, CodingKey {
    case graduationYear = "graduation_year"
    case highSchool = "high_school"
    case clubTeam = "club_team"
    case primarySport = "primary_sport"
    case primaryPosition = "primary_position"
    case positions
    case bats
    case throws_ = "throws"
    case heightInches = "height_inches"
    case weightLbs = "weight_lbs"
    case shootingHand = "shooting_hand"
    case dominantFoot = "dominant_foot"
    case hittingHand = "hitting_hand"
    case racketHand = "racket_hand"
    case backhandStyle = "backhand_style"
    case golfHandedness = "golf_handedness"
    case dominantHand = "dominant_hand"
    case shoots
    case catches
    case wpDominantHand = "wp_dominant_hand"
    case rowingSide = "rowing_side"
    case rowingDiscipline = "rowing_discipline"
    case throwingHand = "throwing_hand"
    case kickingFoot = "kicking_foot"
    case gpa
    case satScore = "sat_score"
    case actScore = "act_score"
    case coreCourses = "core_courses"
    case intendedMajor = "intended_major"
    case ncaaId = "ncaa_id"
    case perfectGameId = "perfect_game_id"
    case prepBaseballId = "prep_baseball_id"
    case prepBaseballState = "prep_baseball_state"
    case ncsaId = "ncsa_id"
    case hudlUrl = "hudl_url"
    case athleticNetId = "athletic_net_id"
    case milesplitUrl = "milesplit_url"
    case swimcloudId = "swimcloud_id"
    case utrId = "utr_id"
    case tennisRecruitingId = "tennis_recruiting_id"
    case eliteProspectsId = "elite_prospects_id"
    case sportsrecruitsId = "sportsrecruits_id"
    case concept2Id = "concept2_id"
    case on3Url = "on3_url"
    case sports247Url = "sports247_url"
    case twitterHandle = "twitter_handle"
    case instagramHandle = "instagram_handle"
    case tiktokHandle = "tiktok_handle"
    case facebookUrl = "facebook_url"
    case phone
    case email
    case allowSharePhone = "allow_share_phone"
    case allowShareEmail = "allow_share_email"
    case campusSizePreference = "campus_size_preference"
    case costSensitivity = "cost_sensitivity"
    case gender
    case schoolName = "school_name"
    case schoolAddress = "school_address"
    case schoolCity = "school_city"
    case schoolState = "school_state"
    case ninthGradeTeam = "ninth_grade_team"
    case ninthGradeCoach = "ninth_grade_coach"
    case tenthGradeTeam = "tenth_grade_team"
    case tenthGradeCoach = "tenth_grade_coach"
    case eleventhGradeTeam = "eleventh_grade_team"
    case eleventhGradeCoach = "eleventh_grade_coach"
    case twelfthGradeTeam = "twelfth_grade_team"
    case twelfthGradeCoach = "twelfth_grade_coach"
    case travelTeamYear = "travel_team_year"
    case travelTeamName = "travel_team_name"
    case travelTeamCoach = "travel_team_coach"
    case travelTeams = "travel_teams"
  }
}
