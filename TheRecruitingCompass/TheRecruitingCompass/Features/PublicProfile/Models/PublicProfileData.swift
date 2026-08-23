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
