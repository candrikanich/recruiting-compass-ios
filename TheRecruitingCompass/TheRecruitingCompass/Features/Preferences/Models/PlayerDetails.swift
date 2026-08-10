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

  // Academics
  var gpa: Double? // 0.0-5.0
  var satScore: Int? // 400-1600
  var actScore: Int? // 1-36
  var coreCourses: [String]? // AP/honors/notable courses (max 20)

  // External IDs
  var ncaaId: String?
  var perfectGameId: String?
  var prepBaseballId: String?

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

  var isBaseballOrSoftball: Bool {
    guard let sport = primarySport?.lowercased() else { return false }
    return sport == "baseball" || sport == "softball"
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

  /// True only when every canonical field is filled. Drives the Settings "Complete" badge.
  func isComplete(hasHighlightVideo: Bool, hasHomeLocation: Bool) -> Bool {
    completenessScore(hasHighlightVideo: hasHighlightVideo, hasHomeLocation: hasHomeLocation) >= 1.0
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
    case gpa
    case satScore = "sat_score"
    case actScore = "act_score"
    case coreCourses = "core_courses"
    case ncaaId = "ncaa_id"
    case perfectGameId = "perfect_game_id"
    case prepBaseballId = "prep_baseball_id"
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
