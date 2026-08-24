import Foundation

/// Aggregated, render-ready content for the recruiting packet PDF. Mirrors the web
/// `RecruitingPacketData` shape (`utils/recruitingPacketExport.ts`) so the two platforms
/// present the same packet. Pure value type — building it has no side effects.
struct RecruitingPacketData: Equatable {

  struct Athlete: Equatable {
    var fullName: String?
    var email: String?
    var phone: String?          // already gated by allow_share_phone before it lands here
    var height: String?         // "6'2\""
    var weight: String?         // "185 lbs"
    var position: String?       // coach-facing short form, e.g. "3B/SS"
    var batsThrows: String?     // "R/R", degrades to "R/—"
    var schoolName: String?     // high school / school_name
    var graduationYear: Int?
    var gpa: Double?
    var satScore: Int?
    var actScore: Int?
    var coreCourses: [String]
    var videoLinks: [VideoLinkEntry]
    var socialMedia: [SocialEntry]
  }

  struct VideoLinkEntry: Equatable {
    var label: String           // title, else platform display name
    var url: String
  }

  struct SocialEntry: Equatable {
    var platform: String        // "Instagram" / "X (Twitter)" / "TikTok"
    var handle: String
  }

  struct SchoolRow: Equatable {
    var name: String
    var location: String
    var division: String
    var conference: String
    var status: String          // display name
  }

  struct SchoolTiers: Equatable {
    var tierA: [SchoolRow]       // offer_received | committed
    var tierB: [SchoolRow]       // visiting
    var tierC: [SchoolRow]       // everything else
  }

  struct ActivitySummary: Equatable {
    var totalSchools: Int
    var totalInteractions: Int
    var recentContact: Date?
    var emails: Int
    var calls: Int
    var camps: Int
    var visits: Int
    var other: Int
  }

  var athlete: Athlete
  var tiers: SchoolTiers
  var activity: ActivitySummary

  // MARK: - Pure aggregation

  /// Groups schools into priority tiers by status. Mirrors web `groupSchoolsByTier`:
  /// A = offer_received | committed, B = visiting, C = everything else (incl. deprecated statuses).
  static func groupSchoolsByTier(_ schools: [School]) -> SchoolTiers {
    var tierA: [SchoolRow] = []
    var tierB: [SchoolRow] = []
    var tierC: [SchoolRow] = []

    for school in schools {
      let row = schoolRow(school)
      switch SchoolStatus(rawValue: school.status) ?? .unknown {
      case .offerReceived, .committed:
        tierA.append(row)
      case .visiting:
        tierB.append(row)
      default:
        tierC.append(row)
      }
    }
    return SchoolTiers(tierA: tierA, tierB: tierB, tierC: tierC)
  }

  static func schoolRow(_ school: School) -> SchoolRow {
    let assembledLocation = school.location
      ?? [school.city, school.state].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    let status = SchoolStatus(rawValue: school.status)?.displayName ?? school.status
    return SchoolRow(
      name: school.name,
      location: assembledLocation.isEmpty ? "—" : assembledLocation,
      division: school.division?.isEmpty == false ? school.division! : "—",
      conference: school.conference?.isEmpty == false ? school.conference! : "—",
      status: status
    )
  }

  /// Builds the activity summary from interactions. Mirrors web `calculateActivitySummary` /
  /// `interactionBreakdown` bucketing.
  static func activitySummary(schoolCount: Int, interactions: [Interaction]) -> ActivitySummary {
    var emails = 0, calls = 0, camps = 0, visits = 0, other = 0
    var recent: Date?

    for interaction in interactions {
      switch interaction.type {
      case .email:
        emails += 1
      case .phoneCall:
        calls += 1
      case .camp, .showcase:
        camps += 1
      case .inPersonVisit, .unofficialVisit, .officialVisit, .virtualMeeting:
        visits += 1
      default:
        other += 1
      }
      let date = interaction.displayDate
      if let current = recent {
        if date > current { recent = date }
      } else {
        recent = date
      }
    }

    return ActivitySummary(
      totalSchools: schoolCount,
      totalInteractions: interactions.count,
      recentContact: recent,
      emails: emails,
      calls: calls,
      camps: camps,
      visits: visits,
      other: other
    )
  }

  /// Combines a bats value and a throws value into "R/R", degrading to "R/—" when only one is set.
  /// Returns nil when neither is set.
  static func batsThrows(bats: String?, throws throwsValue: String?) -> String? {
    let batsTrimmed = bats?.trimmingCharacters(in: .whitespaces)
    let throwsTrimmed = throwsValue?.trimmingCharacters(in: .whitespaces)
    let batsFilled = !(batsTrimmed ?? "").isEmpty
    let throwsFilled = !(throwsTrimmed ?? "").isEmpty
    guard batsFilled || throwsFilled else { return nil }
    return "\(batsFilled ? batsTrimmed! : "—")/\(throwsFilled ? throwsTrimmed! : "—")"
  }

  static func socialEntries(instagram: String?, twitter: String?, tiktok: String?) -> [SocialEntry] {
    var entries: [SocialEntry] = []
    func add(_ platform: String, _ handle: String?) {
      let value = handle?.trimmingCharacters(in: .whitespaces) ?? ""
      guard !value.isEmpty else { return }
      entries.append(SocialEntry(platform: platform, handle: value))
    }
    add("Instagram", instagram)
    add("X (Twitter)", twitter)
    add("TikTok", tiktok)
    return entries
  }
}
