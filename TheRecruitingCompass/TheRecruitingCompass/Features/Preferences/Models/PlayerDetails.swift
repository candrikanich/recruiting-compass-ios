import Foundation

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

  // Travel Team
  var travelTeamYear: Int?
  var travelTeamName: String?
  var travelTeamCoach: String?

  static var `default`: PlayerDetails {
    PlayerDetails()
  }

  var isBaseballOrSoftball: Bool {
    guard let sport = primarySport?.lowercased() else { return false }
    return sport == "baseball" || sport == "softball"
  }

  /// Fraction (0.0–1.0) of required profile fields that are filled. Single source
  /// of truth for both the Player Details completeness card and the Settings badge.
  /// SAT and ACT count as one field — most athletes take only one.
  var completenessScore: Double {
    var fields: [Bool] = [
      graduationYear != nil,
      !(highSchool ?? "").isEmpty,
      !(primarySport ?? "").isEmpty,
      !(schoolName ?? "").isEmpty,
      !(schoolCity ?? "").isEmpty,
      !(schoolState ?? "").isEmpty,
      heightInches != nil,
      weightLbs != nil,
      gpa != nil,
      satScore != nil || actScore != nil,
      !(twitterHandle ?? "").isEmpty || !(instagramHandle ?? "").isEmpty
    ]
    if isBaseballOrSoftball {
      fields.append(bats != nil)
      fields.append(throws_ != nil)
    }
    let filled = fields.count(where: { $0 })
    return Double(filled) / Double(fields.count)
  }

  /// True only when every required field is filled. Drives the Settings "Complete" badge.
  var isComplete: Bool { completenessScore >= 1.0 }

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
  }
}
