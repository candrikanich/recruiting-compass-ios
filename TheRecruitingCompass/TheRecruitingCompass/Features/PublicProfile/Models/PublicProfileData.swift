import Foundation

/// Native card input, assembled on-device from existing iOS services.
/// NOT decoded from the API (the API's PublicProfileData is a web-only concern).
struct PublicProfileData: Equatable, Sendable {
    let playerName: String
    let photoUrl: String?
    let headerColor: HeaderColor
    let bio: String?
    let academics: AcademicsSection?
    let athletic: AthleticSection?
    let film: [FilmItem]?
    let schools: [SchoolItem]?
    let social: SocialSection?

    struct AcademicsSection: Equatable, Sendable {
        let gpa: Double?
        let satScore: Int?
        let actScore: Int?
        let graduationYear: Int?
        let highSchool: String?
        let coreCourses: [String]?
    }

    struct AthleticSection: Equatable, Sendable {
        let primarySport: String?
        let primaryPosition: String?
        let positions: [String]?
        let heightInches: Int?
        let weightLbs: Int?
        let ncaaId: String?
        let perfectGameId: String?
        let prepBaseballId: String?
        let prepBaseballState: String?
        // Services v2 — surfaced on the public card via the sport-gated registry.
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

    struct FilmItem: Equatable, Sendable {
        let title: String?
        let url: String
    }

    struct SchoolItem: Equatable, Sendable {
        let id: String
        let name: String
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
