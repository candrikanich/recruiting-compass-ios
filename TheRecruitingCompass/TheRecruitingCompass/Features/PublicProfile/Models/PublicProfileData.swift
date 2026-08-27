import Foundation

/// Native card input, assembled on-device from existing iOS services.
/// NOT decoded from the API (the API's PublicProfileData is a web-only concern).
/// Mirrors the section model shipped by web PRs #500–510 (see
/// `planning/iOS_SPEC_public-profile-and-setup-2026-08-26.md`): six
/// reorderable/hideable sections — metrics, film, academics, values,
/// team_history, awards — plus a credentials row folded into metrics and a
/// hero physicals line. The old standalone "Target Schools" list is gone
/// (privacy: never leak the athlete's followed schools to a visitor).
struct PublicProfileData: Equatable, Sendable {
    let playerName: String
    let photoUrl: String?
    let headerColor: HeaderColor
    let bio: String?
    let academics: AcademicsSection?
    let credentials: CredentialsRow?
    let metrics: [MetricEntry]?
    let film: [FilmItem]?
    let lookingFor: String?
    let valuesTags: [String]
    let teamHistory: [TeamHistoryEntry]?
    let awards: [AwardEntry]?
    let social: SocialSection?
    let commitmentStatus: CommitmentStatus
    let committedSchoolName: String?
    let updatedAt: Date?
    /// Owner-visible sections, in owner-chosen order (already filtered to
    /// `visible == true`). Drives render order + the academics/values and
    /// team_history/awards 2-col pairing, parity with web `PublicProfileCard.vue`.
    let visibleSectionOrder: [ProfileSectionKey]

    struct AcademicsSection: Equatable, Sendable {
        let gpa: Double?
        let satScore: Int?
        let actScore: Int?
        let graduationYear: Int?
        let highSchool: String?
        let intendedMajor: String?
        let coreCourses: [String]?
    }

    /// Physicals + recruiting-ID credentials, folded from the old "Athletic"
    /// section into the hero physicals line + the Metrics section's
    /// credentials row (parity with web `RecruitingCredentials`).
    struct CredentialsRow: Equatable, Sendable {
        let primarySport: String?
        let primaryPosition: String?
        let positions: [String]?
        let heightInches: Int?
        let weightLbs: Int?
        let ncaaId: String?
        let perfectGameId: String?
        let prepBaseballId: String?
        let prepBaseballState: String?
        let athleticNetId: String?
        let milesplitUrl: String?
        let swimcloudId: String?
        let utrId: String?
        let tennisRecruitingId: String?
        let eliteProspectsId: String?
        let sportsrecruitsId: String?
        let concept2Id: String?
        let on3Url: String?
        let sports247Url: String?

        init(
            primarySport: String?, primaryPosition: String?, positions: [String]?,
            heightInches: Int?, weightLbs: Int?, ncaaId: String?, perfectGameId: String?,
            prepBaseballId: String?, prepBaseballState: String?,
            athleticNetId: String? = nil, milesplitUrl: String? = nil,
            swimcloudId: String? = nil, utrId: String? = nil,
            tennisRecruitingId: String? = nil, eliteProspectsId: String? = nil,
            sportsrecruitsId: String? = nil, concept2Id: String? = nil,
            on3Url: String? = nil, sports247Url: String? = nil
        ) {
            self.primarySport = primarySport
            self.primaryPosition = primaryPosition
            self.positions = positions
            self.heightInches = heightInches
            self.weightLbs = weightLbs
            self.ncaaId = ncaaId
            self.perfectGameId = perfectGameId
            self.prepBaseballId = prepBaseballId
            self.prepBaseballState = prepBaseballState
            self.athleticNetId = athleticNetId
            self.milesplitUrl = milesplitUrl
            self.swimcloudId = swimcloudId
            self.utrId = utrId
            self.tennisRecruitingId = tennisRecruitingId
            self.eliteProspectsId = eliteProspectsId
            self.sportsrecruitsId = sportsrecruitsId
            self.concept2Id = concept2Id
            self.on3Url = on3Url
            self.sports247Url = sports247Url
        }

        /// Stored value for a v2 service key, matching `RecruitingServices` keys.
        func serviceValue(forKey key: String) -> String? {
            switch key {
            case "athletic_net_id": return athleticNetId
            case "milesplit_url": return milesplitUrl
            case "swimcloud_id": return swimcloudId
            case "utr_id": return utrId
            case "tennis_recruiting_id": return tennisRecruitingId
            case "elite_prospects_id": return eliteProspectsId
            case "sportsrecruits_id": return sportsrecruitsId
            case "concept2_id": return concept2Id
            case "on3_url": return on3Url
            case "sports247_url": return sports247Url
            default: return nil
            }
        }
    }

    /// One formatted metric card. `value`/`unit` come from `MetricRegistry`
    /// (the stored DB `unit`/`display_value` carry stale/garbage data), one
    /// entry per `metric_type`, newest wins on duplicates.
    struct MetricEntry: Equatable, Sendable, Identifiable {
        let key: String
        let label: String
        let value: String
        let unit: String
        let verified: Bool
        var id: String { key }
    }

    struct FilmItem: Equatable, Sendable {
        let title: String?
        let url: String
    }

    /// One team-history row (grade-level school team or travel/club team).
    /// `contact` mirrors web's `PublicTeamHistoryEntry.contact` — always nil
    /// today (no reference-phone field exists yet on either platform); render
    /// only when present, per spec.
    struct TeamHistoryEntry: Equatable, Sendable, Identifiable {
        let name: String
        let level: String
        let coach: String?
        let contact: String?
        let years: String?
        var id: String { "\(level)-\(name)" }
    }

    struct AwardEntry: Equatable, Sendable, Identifiable {
        let title: String
        let year: Int?
        var id: String { "\(title)-\(year.map(String.init) ?? "")" }
    }

    struct SocialSection: Equatable, Sendable {
        let twitterHandle: String?
        let instagramHandle: String?
        let tiktokHandle: String?
        let facebookUrl: String?

        var isEmpty: Bool {
            [twitterHandle, instagramHandle, tiktokHandle, facebookUrl]
                .allSatisfy { $0?.trimmingCharacters(in: .whitespaces).isEmpty ?? true }
        }
    }
}
