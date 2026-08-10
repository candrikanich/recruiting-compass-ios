# iOS Public Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a full-parity "Public Profile" tab to the iOS Player Profile screen — editor, native preview card, and per-coach Send Profile tracking — reusing the existing web API and Supabase backend.

**Architecture:** New `Features/PublicProfile/` MVVM module. A `PublicProfileServiceImpl` wraps the web REST API (`/api/player/profile`, tracking-links) using the established `DashboardServiceImpl` pattern (Bearer token + CSRF for mutations, graceful degrade when `API_BASE_URL` unset). A `PublicProfileViewModel` (`@Observable @MainActor`) drives an editor and assembles a `PublicProfileData` from existing iOS services (Preferences `.player`, Schools, ProfilePhoto, VideoLinks) for a native `PublicProfileCard`. Wired as a 5th segment on `PlayerDetailsView`; Send Profile added to iOS coach detail.

**Tech Stack:** Swift 6, SwiftUI, `@Observable`, Supabase Swift SDK (auth token only), `URLSession`, XCTest.

## Global Constraints

- **Path structure:** source lives at `TheRecruitingCompass/TheRecruitingCompass/…`; tests at `TheRecruitingCompass/TheRecruitingCompassTests/…` (double-nested — a common mistake).
- **Build/test dir:** run all `xcodebuild` from `TheRecruitingCompass/` (the Xcode project wrapper), destination `platform=iOS Simulator,name=iPhone 17`.
- **No `.xcodeproj` edits:** project uses `PBXFileSystemSynchronizedRootGroup` — new `.swift` files auto-included. Never run `add_files_to_xcode.rb`.
- **macOS 26 rule:** every new `@MainActor` class (production AND `XCTestCase`) needs `nonisolated deinit {}`.
- **UIKit off-main crash:** unit tests run off-main; any test touching `UIColor`/`UIFont`/`UIImage` rendering must be `@MainActor` + `async`.
- **MVVM strict:** ViewModels `@Observable @MainActor`; Services `protocol : Sendable`, NOT `@MainActor`. Views presentation-only.
- **Localization:** user-facing strings via `String(localized:)`.
- **Line length ≤120** (SwiftLint). Run `swiftlint --config .swiftlint.yml` (bare invocation gives false errors).
- **Web API auth:** `Authorization: Bearer <authManager.session?.accessToken>`; on 401 → `authManager.refreshSession()` → retry once.
- **Web API mutations (PUT/POST):** require CSRF — `GET /api/csrf-token`, read `csrf-token` cookie, send `x-csrf-token` header. Reads (GET) do not.
- **`API_BASE_URL` unset:** `SupabaseConfig.apiBaseURL` is `URL?` (nil in DEBUG). All API methods guard it and degrade gracefully — no throw, editor shows web-setup message.
- **Reserved slugs (server-rejected 422):** `api, p, auth, login, signup, join, admin, settings, dashboard, coaches, schools, help`.
- **vanity_slug regex:** `^[a-z0-9][a-z0-9-]{0,28}[a-z0-9]$`; empty string clears to `null`.
- **header_color enum:** `slate, blue, emerald, violet, rose, amber, teal, indigo` (default `slate`).

---

## File Structure

```
Features/PublicProfile/
├── Models/
│   ├── PlayerProfile.swift          (PlayerProfile, ProfileTrackingLink, UpdateProfilePayload)
│   ├── HeaderColor.swift            (8-preset enum + Color mapping)
│   └── PublicProfileData.swift      (native card VM input + sub-structs)
├── Services/
│   ├── PublicProfileManaging.swift  (protocol + PublicProfileAPIError)
│   ├── PublicProfileServiceImpl.swift
│   └── MockPublicProfileManaging.swift
├── ViewModels/
│   └── PublicProfileViewModel.swift
├── Views/
│   ├── PublicTab.swift              (editor + preview container)
│   └── PublicProfileCard.swift      (native coach-facing card)
└── Components/
    ├── HeaderColorPicker.swift
    └── ShareLinkRow.swift
```
Modified: `Features/Preferences/Views/PlayerDetailsView.swift` (5th segment); iOS coach detail view (Send Profile).

Tests mirror under `TheRecruitingCompassTests/Features/PublicProfile/`.

---

## Task 1: Models — PlayerProfile, ProfileTrackingLink, UpdateProfilePayload

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Models/PlayerProfile.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Models/PlayerProfileTests.swift`

**Interfaces:**
- Produces: `struct PlayerProfile: Codable, Equatable, Sendable`, `struct ProfileTrackingLink: Codable, Equatable, Sendable`, `struct UpdateProfilePayload: Encodable, Equatable`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

final class PlayerProfileTests: XCTestCase {
    nonisolated deinit {}

    func testDecodesSnakeCaseRowFromAPI() throws {
        let json = """
        {
          "id": "p1", "user_id": "u1", "family_unit_id": "f1",
          "hash_slug": "ab12cd", "vanity_slug": null, "is_published": false,
          "bio": null, "header_color": "slate",
          "show_academics": true, "show_athletic": true,
          "show_film": true, "show_schools": true,
          "created_at": "2026-08-10T00:00:00Z", "updated_at": "2026-08-10T00:00:00Z"
        }
        """.data(using: .utf8)!
        let profile = try JSONDecoder().decode(PlayerProfile.self, from: json)
        XCTAssertEqual(profile.hashSlug, "ab12cd")
        XCTAssertNil(profile.vanitySlug)
        XCTAssertFalse(profile.isPublished)
        XCTAssertEqual(profile.headerColor, "slate")
        XCTAssertTrue(profile.showFilm)
    }

    func testUpdatePayloadOmitsNilFields() throws {
        let payload = UpdateProfilePayload(isPublished: true)
        let data = try JSONEncoder().encode(payload)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["is_published"] as? Bool, true)
        XCTAssertNil(obj["bio"])
        XCTAssertNil(obj["vanity_slug"])
    }

    func testTrackingLinkDecodes() throws {
        let json = """
        {"id":"t1","profile_id":"p1","coach_id":"c1","ref_token":"a1b2c3d4",
         "view_count":3,"last_viewed_at":null,"created_at":"2026-08-10T00:00:00Z"}
        """.data(using: .utf8)!
        let link = try JSONDecoder().decode(ProfileTrackingLink.self, from: json)
        XCTAssertEqual(link.refToken, "a1b2c3d4")
        XCTAssertEqual(link.viewCount, 3)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/PlayerProfileTests`
Expected: FAIL — `cannot find 'PlayerProfile' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: same command as Step 2.
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Models/PlayerProfile.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Models/PlayerProfileTests.swift
git commit -m "feat(public-profile): PlayerProfile + tracking-link + update-payload models"
```

---

## Task 2: HeaderColor presets

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Models/HeaderColor.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Models/HeaderColorTests.swift`

**Interfaces:**
- Produces: `enum HeaderColor: String, CaseIterable, Sendable` with cases `slate, blue, emerald, violet, rose, amber, teal, indigo`; `var label: String`; `var color: Color`; `static func from(_ key: String) -> HeaderColor` (defaults to `.slate`).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class HeaderColorTests: XCTestCase {
    nonisolated deinit {}

    func testAllEightKeysPresent() {
        XCTAssertEqual(
            Set(HeaderColor.allCases.map(\.rawValue)),
            ["slate", "blue", "emerald", "violet", "rose", "amber", "teal", "indigo"]
        )
    }

    func testFromUnknownDefaultsToSlate() {
        XCTAssertEqual(HeaderColor.from("chartreuse"), .slate)
        XCTAssertEqual(HeaderColor.from("blue"), .blue)
    }

    func testEveryCaseHasNonEmptyLabel() {
        for c in HeaderColor.allCases { XCTAssertFalse(c.label.isEmpty) }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/HeaderColorTests`
Expected: FAIL — `cannot find 'HeaderColor' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import SwiftUI

/// Mirrors web ProfileSetup.vue HEADER_COLORS. Tailwind -700 swatches
/// approximated as sRGB hex; family-recognizable, exact match not required.
enum HeaderColor: String, CaseIterable, Sendable {
    case slate, blue, indigo, violet, rose, amber, emerald, teal

    var label: String {
        switch self {
        case .slate: return String(localized: "Slate")
        case .blue: return String(localized: "Blue")
        case .indigo: return String(localized: "Indigo")
        case .violet: return String(localized: "Violet")
        case .rose: return String(localized: "Rose")
        case .amber: return String(localized: "Amber")
        case .emerald: return String(localized: "Emerald")
        case .teal: return String(localized: "Teal")
        }
    }

    var color: Color {
        switch self {
        case .slate: return Color(hex: 0x334155)
        case .blue: return Color(hex: 0x1D4ED8)
        case .indigo: return Color(hex: 0x4338CA)
        case .violet: return Color(hex: 0x6D28D9)
        case .rose: return Color(hex: 0xBE123C)
        case .amber: return Color(hex: 0xD97706)
        case .emerald: return Color(hex: 0x047857)
        case .teal: return Color(hex: 0x0F766E)
        }
    }

    static func from(_ key: String) -> HeaderColor {
        HeaderColor(rawValue: key) ?? .slate
    }
}
```

Note: Step 3 uses a `Color(hex:)` initializer. Before implementing, grep for an existing one:
`grep -rn "init(hex" TheRecruitingCompass/TheRecruitingCompass/Core`. If found, use it and delete
the fallback below. If NOT found, add this fileprivate helper to `HeaderColor.swift`:

```swift
fileprivate extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Models/HeaderColor.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Models/HeaderColorTests.swift
git commit -m "feat(public-profile): header color presets"
```

---

## Task 3: PublicProfileData card-input model

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Models/PublicProfileData.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Models/PublicProfileDataTests.swift`

**Interfaces:**
- Consumes: `HeaderColor` (Task 2).
- Produces: `struct PublicProfileData: Equatable, Sendable` with `playerName: String`, `photoUrl: String?`, `headerColor: HeaderColor`, `bio: String?`, `academics: AcademicsSection?`, `athletic: AthleticSection?`, `film: [FilmItem]?`, `schools: [SchoolItem]?`; nested `AcademicsSection`, `AthleticSection`, `FilmItem`, `SchoolItem` (all `Equatable, Sendable`). This is a pure view model assembled on-device (never decoded from the API).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

final class PublicProfileDataTests: XCTestCase {
    nonisolated deinit {}

    func testConstructsWithAllSectionsNil() {
        let data = PublicProfileData(
            playerName: "Jordan Rivera", photoUrl: nil,
            headerColor: .slate, bio: nil,
            academics: nil, athletic: nil, film: nil, schools: nil
        )
        XCTAssertEqual(data.playerName, "Jordan Rivera")
        XCTAssertNil(data.athletic)
    }

    func testEquatableAcrossNestedSections() {
        let a = PublicProfileData.FilmItem(title: "Senior Highlights", url: "https://x/y")
        let b = PublicProfileData.FilmItem(title: "Senior Highlights", url: "https://x/y")
        XCTAssertEqual(a, b)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/PublicProfileDataTests`
Expected: FAIL — `cannot find 'PublicProfileData' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
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
    }

    struct FilmItem: Equatable, Sendable {
        let title: String?
        let url: String
    }

    struct SchoolItem: Equatable, Sendable {
        let id: String
        let name: String
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Models/PublicProfileData.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Models/PublicProfileDataTests.swift
git commit -m "feat(public-profile): native card-input model"
```

---

## Task 4: Service protocol, error type, and Mock

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Services/PublicProfileManaging.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Services/MockPublicProfileManaging.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Services/MockPublicProfileManagingTests.swift`

**Interfaces:**
- Consumes: `PlayerProfile`, `ProfileTrackingLink`, `UpdateProfilePayload` (Task 1).
- Produces:
  - `protocol PublicProfileManaging: Sendable` with:
    - `func fetchProfile(accessToken: String?) async throws -> PlayerProfile?`
    - `func updateProfile(_ payload: UpdateProfilePayload, accessToken: String?) async throws`
    - `func fetchTrackingLink(coachId: String, accessToken: String?) async throws -> ProfileTrackingLink?`
    - `func createTrackingLink(coachId: String, accessToken: String?) async throws -> ProfileTrackingLink`
  - `enum PublicProfileAPIError: Error, Equatable { case unauthorized, slugTaken, slugInvalid, notMember, notConfigured, server(Int) }`
  - `final class MockPublicProfileManaging: PublicProfileManaging, @unchecked Sendable` with settable stubs (`stubProfile`, `stubTrackingLink`, `errorToThrow`) and call spies (`updatedPayloads: [UpdateProfilePayload]`, `createdCoachIds: [String]`).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

final class MockPublicProfileManagingTests: XCTestCase {
    nonisolated deinit {}

    func testMockReturnsStubProfile() async throws {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = PlayerProfile(
            id: "p1", userId: "u1", familyUnitId: "f1", hashSlug: "ab12cd",
            vanitySlug: nil, isPublished: false, bio: nil, headerColor: "slate",
            showAcademics: true, showAthletic: true, showFilm: true, showSchools: true,
            createdAt: "", updatedAt: ""
        )
        let result = try await mock.fetchProfile(accessToken: "t")
        XCTAssertEqual(result?.hashSlug, "ab12cd")
    }

    func testMockRecordsUpdatePayload() async throws {
        let mock = MockPublicProfileManaging()
        try await mock.updateProfile(UpdateProfilePayload(isPublished: true), accessToken: "t")
        XCTAssertEqual(mock.updatedPayloads.count, 1)
        XCTAssertEqual(mock.updatedPayloads.first?.isPublished, true)
    }

    func testMockThrowsConfiguredError() async {
        let mock = MockPublicProfileManaging()
        mock.errorToThrow = PublicProfileAPIError.slugTaken
        do {
            _ = try await mock.createTrackingLink(coachId: "c1", accessToken: "t")
            XCTFail("expected throw")
        } catch let e as PublicProfileAPIError {
            XCTAssertEqual(e, .slugTaken)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/MockPublicProfileManagingTests`
Expected: FAIL — `cannot find 'MockPublicProfileManaging' in scope`.

- [ ] **Step 3: Write minimal implementation**

`PublicProfileManaging.swift`:

```swift
import Foundation

enum PublicProfileAPIError: Error, Equatable {
    case unauthorized
    case slugTaken
    case slugInvalid
    case notMember
    case notConfigured
    case server(Int)
}

protocol PublicProfileManaging: Sendable {
    func fetchProfile(accessToken: String?) async throws -> PlayerProfile?
    func updateProfile(_ payload: UpdateProfilePayload, accessToken: String?) async throws
    func fetchTrackingLink(coachId: String, accessToken: String?) async throws -> ProfileTrackingLink?
    func createTrackingLink(coachId: String, accessToken: String?) async throws -> ProfileTrackingLink
}
```

`MockPublicProfileManaging.swift`:

```swift
import Foundation

final class MockPublicProfileManaging: PublicProfileManaging, @unchecked Sendable {
    var stubProfile: PlayerProfile?
    var stubTrackingLink: ProfileTrackingLink?
    var errorToThrow: Error?
    private(set) var updatedPayloads: [UpdateProfilePayload] = []
    private(set) var createdCoachIds: [String] = []
    private(set) var fetchedTrackingCoachIds: [String] = []

    func fetchProfile(accessToken: String?) async throws -> PlayerProfile? {
        if let errorToThrow { throw errorToThrow }
        return stubProfile
    }

    func updateProfile(_ payload: UpdateProfilePayload, accessToken: String?) async throws {
        if let errorToThrow { throw errorToThrow }
        updatedPayloads.append(payload)
    }

    func fetchTrackingLink(coachId: String, accessToken: String?) async throws -> ProfileTrackingLink? {
        if let errorToThrow { throw errorToThrow }
        fetchedTrackingCoachIds.append(coachId)
        return stubTrackingLink
    }

    func createTrackingLink(coachId: String, accessToken: String?) async throws -> ProfileTrackingLink {
        if let errorToThrow { throw errorToThrow }
        createdCoachIds.append(coachId)
        guard let stub = stubTrackingLink else {
            return ProfileTrackingLink(
                id: "mock", profileId: "p1", coachId: coachId,
                refToken: "mock1234", viewCount: 0, lastViewedAt: nil, createdAt: ""
            )
        }
        return stub
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Services/PublicProfileManaging.swift TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Services/MockPublicProfileManaging.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Services/MockPublicProfileManagingTests.swift
git commit -m "feat(public-profile): service protocol, error type, mock"
```

---

## Task 5: PublicProfileServiceImpl (web API client)

**Files:**
- Reference first (read, do not modify): `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Services/DashboardServiceImpl.swift` (lines ~158-303 — the `fetchSuggestions`/`dismissSuggestion`/`fetchCSRFToken` pattern to copy).
- Reference: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseConfig.swift:94-113` (`apiBaseURL`).
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Services/PublicProfileServiceImpl.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Services/PublicProfileServiceImplTests.swift`

**Interfaces:**
- Consumes: `PublicProfileManaging`, `PublicProfileAPIError`, models (Tasks 1, 4); `SupabaseConfig.apiBaseURL`.
- Produces: `struct PublicProfileServiceImpl: PublicProfileManaging` with an injectable `URLSession` (default `.shared`) so tests use a `URLProtocol` stub. Endpoints:
  - GET `api/player/profile`
  - PUT `api/player/profile` (CSRF)
  - GET `api/player/profile/tracking-links/{coachId}`
  - POST `api/player/profile/tracking-links/{coachId}` (CSRF)

**Design notes for the implementer:**
- Guard `SupabaseConfig.apiBaseURL` and non-empty token: `fetchProfile` returns `nil` when unconfigured (parity with Suggestions); mutations throw `.notConfigured`.
- Status mapping: 401 → `.unauthorized`; 409 → `.slugTaken`; 422 → `.slugInvalid`; 403 → `.notMember`; other non-2xx → `.server(code)`.
- CSRF for PUT/POST only: reuse the exact `fetchCSRFToken(baseURL:)` approach from `DashboardServiceImpl` (GET `api/csrf-token`, read `csrf-token` cookie via `HTTPCookieStorage.shared.cookies(for: baseURL.appendingPathComponent("api"))`, send `x-csrf-token`). Extract a private helper; do not duplicate inline.
- `URLSession` injected via init for `URLProtocol` testing.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

final class PublicProfileServiceImplTests: XCTestCase {
    nonisolated deinit {}

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    func testFetchProfileReturnsNilWhenTokenMissing() async throws {
        let service = PublicProfileServiceImpl(session: makeSession())
        let result = try await service.fetchProfile(accessToken: nil)
        XCTAssertNil(result)  // no token → treated as unconfigured, no throw
    }

    func testFetchProfileDecodes200() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
            let body = """
            {"id":"p1","user_id":"u1","family_unit_id":"f1","hash_slug":"ab12cd",
             "vanity_slug":null,"is_published":true,"bio":"hi","header_color":"blue",
             "show_academics":true,"show_athletic":true,"show_film":true,"show_schools":true,
             "created_at":"","updated_at":""}
            """.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let service = PublicProfileServiceImpl(session: makeSession())
        let result = try await service.fetchProfile(accessToken: "tok")
        XCTAssertEqual(result?.headerColor, "blue")
        XCTAssertTrue(result?.isPublished == true)
    }

    func testUpdateMaps409ToSlugTaken() async {
        StubURLProtocol.handler = { request in
            // csrf-token GET then PUT: return 200 for csrf, 409 for the PUT
            if request.url!.path.hasSuffix("/csrf-token") {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 409, httpVersion: nil, headerFields: nil)!, Data())
        }
        let service = PublicProfileServiceImpl(session: makeSession())
        do {
            try await service.updateProfile(UpdateProfilePayload(vanitySlug: "taken"), accessToken: "tok")
            XCTFail("expected throw")
        } catch let e as PublicProfileAPIError {
            XCTAssertEqual(e, .slugTaken)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}

/// Minimal URLProtocol stub for injecting HTTP responses in tests.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = StubURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
```

Note: if `SupabaseConfig.apiBaseURL` is `nil` in the DEBUG test environment, `testFetchProfileDecodes200`/`testUpdateMaps409ToSlugTaken` would short-circuit on the base-URL guard before hitting the stub. Before Step 3, verify the test env: `grep -rn "API_BASE_URL" TheRecruitingCompass/TheRecruitingCompass.xcodeproj` and check the test scheme. If `apiBaseURL` is nil under test, make the base URL injectable too — add `baseURLOverride: URL? = nil` to the init and prefer it over `SupabaseConfig.apiBaseURL`; pass `URL(string: "https://test.local")!` from these two tests. Keep `testFetchProfileReturnsNilWhenTokenMissing` (guards on token, not base URL) unchanged.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/PublicProfileServiceImplTests`
Expected: FAIL — `cannot find 'PublicProfileServiceImpl' in scope`.

- [ ] **Step 3: Write minimal implementation**

Implement `PublicProfileServiceImpl` following the `DashboardServiceImpl` pattern. Skeleton (fill CSRF helper by copying `DashboardServiceImpl.fetchCSRFToken`):

```swift
import Foundation
import OSLog

struct PublicProfileServiceImpl: PublicProfileManaging {
    private let session: URLSession
    private let baseURLOverride: URL?
    private let logger = Logger(subsystem: "com.recruitingcompass", category: "PublicProfile")

    init(session: URLSession = .shared, baseURLOverride: URL? = nil) {
        self.session = session
        self.baseURLOverride = baseURLOverride
    }

    private var baseURL: URL? { baseURLOverride ?? SupabaseConfig.apiBaseURL }

    func fetchProfile(accessToken: String?) async throws -> PlayerProfile? {
        guard let baseURL, let token = accessToken, !token.isEmpty else { return nil }
        var request = URLRequest(url: baseURL.appendingPathComponent("api/player/profile"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try Self.mapStatus(response)
        guard !data.isEmpty else { return nil }
        return try JSONDecoder().decode(PlayerProfile.self, from: data)
    }

    func updateProfile(_ payload: UpdateProfilePayload, accessToken: String?) async throws {
        guard let baseURL, let token = accessToken, !token.isEmpty else {
            throw PublicProfileAPIError.notConfigured
        }
        let csrf = try await fetchCSRFToken(baseURL: baseURL)
        var request = URLRequest(url: baseURL.appendingPathComponent("api/player/profile"))
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(csrf, forHTTPHeaderField: "x-csrf-token")
        request.httpBody = try JSONEncoder().encode(payload)
        let (_, response) = try await session.data(for: request)
        try Self.mapStatus(response)
    }

    func fetchTrackingLink(coachId: String, accessToken: String?) async throws -> ProfileTrackingLink? {
        guard let baseURL, let token = accessToken, !token.isEmpty else { return nil }
        let safeId = coachId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? coachId
        let url = baseURL.appendingPathComponent("api/player/profile/tracking-links").appendingPathComponent(safeId)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try Self.mapStatus(response)
        guard !data.isEmpty, (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { return nil }
        return try JSONDecoder().decode(ProfileTrackingLink.self, from: data)
    }

    func createTrackingLink(coachId: String, accessToken: String?) async throws -> ProfileTrackingLink {
        guard let baseURL, let token = accessToken, !token.isEmpty else {
            throw PublicProfileAPIError.notConfigured
        }
        let csrf = try await fetchCSRFToken(baseURL: baseURL)
        let safeId = coachId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? coachId
        let url = baseURL.appendingPathComponent("api/player/profile/tracking-links").appendingPathComponent(safeId)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(csrf, forHTTPHeaderField: "x-csrf-token")
        let (data, response) = try await session.data(for: request)
        try Self.mapStatus(response)
        return try JSONDecoder().decode(ProfileTrackingLink.self, from: data)
    }

    private static func mapStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw PublicProfileAPIError.server(-1) }
        switch http.statusCode {
        case 200...299: return
        case 401: throw PublicProfileAPIError.unauthorized
        case 403: throw PublicProfileAPIError.notMember
        case 409: throw PublicProfileAPIError.slugTaken
        case 422: throw PublicProfileAPIError.slugInvalid
        default: throw PublicProfileAPIError.server(http.statusCode)
        }
    }

    // Copy verbatim from DashboardServiceImpl.fetchCSRFToken (GET api/csrf-token,
    // read csrf-token cookie from HTTPCookieStorage for baseURL/api).
    private func fetchCSRFToken(baseURL: URL) async throws -> String {
        // ... paste the DashboardServiceImpl implementation here ...
        fatalError("copy from DashboardServiceImpl")
    }
}
```

Replace the `fetchCSRFToken` body with the real copy from `DashboardServiceImpl` (do not ship the `fatalError`).

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Services/PublicProfileServiceImpl.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Services/PublicProfileServiceImplTests.swift
git commit -m "feat(public-profile): web API service impl with CSRF + error mapping"
```

---

## Task 6: Slug validation helper

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Models/SlugValidator.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Models/SlugValidatorTests.swift`

**Interfaces:**
- Produces: `enum SlugValidator` with `static func validate(_ raw: String) -> SlugValidation` where `enum SlugValidation: Equatable { case empty, valid, invalidFormat, reserved }`. Reserved list and regex per Global Constraints. Client-side UX only — server remains authority for uniqueness (409).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

final class SlugValidatorTests: XCTestCase {
    nonisolated deinit {}

    func testEmptyIsEmpty() {
        XCTAssertEqual(SlugValidator.validate(""), .empty)
    }
    func testValidSlug() {
        XCTAssertEqual(SlugValidator.validate("jordan-rivera-9"), .valid)
    }
    func testUppercaseIsInvalid() {
        XCTAssertEqual(SlugValidator.validate("Jordan"), .invalidFormat)
    }
    func testLeadingHyphenInvalid() {
        XCTAssertEqual(SlugValidator.validate("-jordan"), .invalidFormat)
    }
    func testTooLongInvalid() {
        XCTAssertEqual(SlugValidator.validate(String(repeating: "a", count: 31)), .invalidFormat)
    }
    func testReservedWord() {
        XCTAssertEqual(SlugValidator.validate("admin"), .reserved)
        XCTAssertEqual(SlugValidator.validate("coaches"), .reserved)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/SlugValidatorTests`
Expected: FAIL — `cannot find 'SlugValidator' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

enum SlugValidation: Equatable {
    case empty, valid, invalidFormat, reserved
}

enum SlugValidator {
    private static let reserved: Set<String> = [
        "api", "p", "auth", "login", "signup", "join", "admin",
        "settings", "dashboard", "coaches", "schools", "help"
    ]
    private static let pattern = "^[a-z0-9][a-z0-9-]{0,28}[a-z0-9]$"

    static func validate(_ raw: String) -> SlugValidation {
        if raw.isEmpty { return .empty }
        if reserved.contains(raw) { return .reserved }
        let matches = raw.range(of: pattern, options: .regularExpression) != nil
        return matches ? .valid : .invalidFormat
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Models/SlugValidator.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Models/SlugValidatorTests.swift
git commit -m "feat(public-profile): client-side slug validation helper"
```

---

## Task 7: PublicProfileViewModel

**Files:**
- Reference (read): `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/ViewModels/PlayerDetailsViewModel.swift` (`effectiveUserId`, `targetUserId`, service injection, load pattern); `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/ViewModels/DashboardViewModel.swift:257-273` (token + 401-refresh-retry).
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/ViewModels/PublicProfileViewModel.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/ViewModels/PublicProfileViewModelTests.swift`

**Interfaces:**
- Consumes: `PublicProfileManaging`, `PlayerProfile`, `UpdateProfilePayload`, `HeaderColor`, `SlugValidator`, `AuthManaging` (existing protocol — inject `authManager` for token/refresh, matching other VMs).
- Produces: `@Observable @MainActor final class PublicProfileViewModel` with:
  - init `(service: PublicProfileManaging, authManager: AuthManaging, targetUserId: String? = nil)`
  - published-ish props: `profile: PlayerProfile?`, `bio: String`, `vanitySlug: String`, `isPublished: Bool`, `headerColor: HeaderColor`, `showAcademics/Athletic/Film/Schools: Bool`, `isLoading: Bool`, `slugError: String?`, `isConfigured: Bool`
  - `func load() async`
  - `func save() async` (builds `UpdateProfilePayload` from current state, calls service, 401→refresh→retry once, maps `.slugTaken`/`.slugInvalid` to `slugError`)
  - `var shareURL: URL?` (computed from slug — see note)
  - `func validateSlug()` (sets `slugError` from `SlugValidator`)
- **shareURL note:** build `SupabaseConfig.apiBaseURL?.appendingPathComponent("p").appendingPathComponent(vanitySlug.isEmpty ? profile.hashSlug : vanitySlug)`. Returns nil when unconfigured or no profile.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class PublicProfileViewModelTests: XCTestCase {
    nonisolated deinit {}

    private func makeProfile(published: Bool = false, slug: String? = nil) -> PlayerProfile {
        PlayerProfile(
            id: "p1", userId: "u1", familyUnitId: "f1", hashSlug: "ab12cd",
            vanitySlug: slug, isPublished: published, bio: "hi", headerColor: "blue",
            showAcademics: true, showAthletic: false, showFilm: true, showSchools: true,
            createdAt: "", updatedAt: ""
        )
    }

    func testLoadPopulatesEditorState() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = makeProfile(published: true, slug: "jordan")
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        await vm.load()
        XCTAssertTrue(vm.isPublished)
        XCTAssertEqual(vm.vanitySlug, "jordan")
        XCTAssertEqual(vm.headerColor, .blue)
        XCTAssertFalse(vm.showAthletic)
    }

    func testSaveSendsCurrentState() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = makeProfile()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        await vm.load()
        vm.isPublished = true
        vm.bio = "updated"
        await vm.save()
        XCTAssertEqual(mock.updatedPayloads.last?.isPublished, true)
        XCTAssertEqual(mock.updatedPayloads.last?.bio, "updated")
    }

    func testSaveMapsSlugTakenToError() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = makeProfile()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        await vm.load()
        mock.errorToThrow = PublicProfileAPIError.slugTaken
        vm.vanitySlug = "taken"
        await vm.save()
        XCTAssertNotNil(vm.slugError)
    }

    func testValidateSlugFlagsReserved() async {
        let mock = MockPublicProfileManaging()
        let vm = PublicProfileViewModel(service: mock, authManager: MockAuthManager())
        vm.vanitySlug = "admin"
        vm.validateSlug()
        XCTAssertNotNil(vm.slugError)
    }
}
```

Note: `MockAuthManager` already exists in the test target (used by auth tests). Confirm its init and that it conforms to `AuthManaging` with a settable/session-returning shape; if its session is nil by default that's fine — the mock service ignores the token. If `MockAuthManager` is not in scope from this test file's target membership, `grep -rn "class MockAuthManager" TheRecruitingCompass/TheRecruitingCompassTests` and mirror its usage.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/PublicProfileViewModelTests`
Expected: FAIL — `cannot find 'PublicProfileViewModel' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class PublicProfileViewModel {
    nonisolated deinit {}

    private let service: PublicProfileManaging
    private let authManager: AuthManaging
    private let targetUserId: String?

    var profile: PlayerProfile?
    var bio: String = ""
    var vanitySlug: String = ""
    var isPublished: Bool = false
    var headerColor: HeaderColor = .slate
    var showAcademics = true
    var showAthletic = true
    var showFilm = true
    var showSchools = true
    var isLoading = false
    var slugError: String?

    var isConfigured: Bool { SupabaseConfig.apiBaseURL != nil }

    init(service: PublicProfileManaging, authManager: AuthManaging, targetUserId: String? = nil) {
        self.service = service
        self.authManager = authManager
        self.targetUserId = targetUserId
    }

    private var token: String? { authManager.session?.accessToken }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let loaded = try await service.fetchProfile(accessToken: token) else { return }
            apply(loaded)
        } catch PublicProfileAPIError.unauthorized {
            await retryAfterRefresh { try await self.service.fetchProfile(accessToken: self.token) }
                .map { if let $0 = $0 { self.apply($0) } }
        } catch {
            // leave state as-is; view shows unconfigured/empty
        }
    }

    func save() async {
        slugError = nil
        validateSlug()
        if slugError != nil { return }
        let payload = UpdateProfilePayload(
            bio: .some(bio.isEmpty ? nil : bio),
            isPublished: isPublished,
            showAcademics: showAcademics, showAthletic: showAthletic,
            showFilm: showFilm, showSchools: showSchools,
            headerColor: headerColor.rawValue,
            vanitySlug: .some(vanitySlug.isEmpty ? nil : vanitySlug)
        )
        do {
            try await service.updateProfile(payload, accessToken: token)
        } catch PublicProfileAPIError.slugTaken {
            slugError = String(localized: "That custom URL is already taken.")
        } catch PublicProfileAPIError.slugInvalid {
            slugError = String(localized: "That custom URL is invalid or reserved.")
        } catch PublicProfileAPIError.unauthorized {
            _ = try? await authManager.refreshSession()
            try? await service.updateProfile(payload, accessToken: token)
        } catch {
            // transient; keep local state
        }
    }

    func validateSlug() {
        switch SlugValidator.validate(vanitySlug) {
        case .empty, .valid: slugError = nil
        case .invalidFormat:
            slugError = String(localized: "Use lowercase letters, numbers, and hyphens only.")
        case .reserved:
            slugError = String(localized: "That custom URL is reserved.")
        }
    }

    var shareURL: URL? {
        guard let profile, let base = SupabaseConfig.apiBaseURL else { return nil }
        let slug = vanitySlug.isEmpty ? profile.hashSlug : vanitySlug
        return base.appendingPathComponent("p").appendingPathComponent(slug)
    }

    private func apply(_ p: PlayerProfile) {
        profile = p
        bio = p.bio ?? ""
        vanitySlug = p.vanitySlug ?? ""
        isPublished = p.isPublished
        headerColor = HeaderColor.from(p.headerColor)
        showAcademics = p.showAcademics
        showAthletic = p.showAthletic
        showFilm = p.showFilm
        showSchools = p.showSchools
    }

    @discardableResult
    private func retryAfterRefresh<T>(_ op: () async throws -> T) async -> T? {
        do { _ = try await authManager.refreshSession(); return try await op() }
        catch { return nil }
    }
}
```

Note: the `.map { if let $0 … }` line in `load()`'s catch is pseudocode — replace with a plain
`if let refreshed = await retryAfterRefresh(...) { apply(refreshed) }`, unwrapping the double
optional (`PlayerProfile??`) correctly. Verify `AuthManaging` exposes `session` and
`refreshSession()`; if the property/method names differ, `grep -rn "protocol AuthManaging" TheRecruitingCompass/TheRecruitingCompass/Core` and adapt.

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/ViewModels/PublicProfileViewModel.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/ViewModels/PublicProfileViewModelTests.swift
git commit -m "feat(public-profile): editor view model with save + slug validation"
```

---

## Task 8: Card-data assembly on the ViewModel

**Files:**
- Reference (read): `PlayerDetailsViewModel.swift` (how it reads `PlayerDetails` via `PreferenceService.fetchPreferences(.player, userId:)`, and `PlayerDetails.swift` field names); `Features/Schools/Services/SchoolsServiceImpl.swift` (`fetchSchools(familyUnitId:)`, `School` fields); `Features/VideoLinks/Services/VideoLinksServiceImpl.swift` (`fetchVideoLinks(userId:)`, `VideoLink` fields); `Features/Profile/Services/ProfilePhotoService.swift` (`currentPhotoURL(userId:)`).
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/ViewModels/PublicProfileViewModel.swift`
- Test: append to `PublicProfileViewModelTests.swift`

**Interfaces:**
- Consumes: `PreferenceManaging`, `SchoolsManaging` (or the concrete service protocols in use), `VideoLinksManaging`, `ProfilePhotoManaging`, `PublicProfileData`, `PlayerDetails`.
- Produces: on `PublicProfileViewModel`:
  - extended init injecting the four existing service protocols (mockable) + `familyUnitId: String?` + player name source
  - `private(set) var cardData: PublicProfileData?`
  - `func assembleCard() async` — reads the four sources scoped to `effectiveUserId`, maps to `PublicProfileData`, honoring live `show_*` toggles (sections gated off when their toggle is false)

**Design notes:**
- `effectiveUserId = targetUserId ?? authManager.user?.id`.
- Section gating uses the VM's live toggle booleans (not the persisted profile) so the preview
  updates immediately when a switch flips.
- Map `PlayerDetails` fields to `AcademicsSection`/`AthleticSection` — read the actual field names
  from `PlayerDetails.swift` (do not guess; e.g. gpa, satScore, actScore, graduationYear,
  highSchool, coreCourses, primarySport, primaryPosition, positions, heightInches, weightLbs,
  ncaaId, perfectGameId, prepBaseballId). If a field is absent on `PlayerDetails`, omit it from the
  section (leave nil) and note it.
- Player name: for current user `authManager.user?.fullName`; for `targetUserId`, reuse the same
  `users` query `ProfilePhotoService` uses (extend to select `full_name`) or an existing name
  lookup if one exists — grep before adding a new query.

- [ ] **Step 1: Write the failing test**

```swift
// Append to PublicProfileViewModelTests. Assumes Mock services exist in the
// test target for PreferenceManaging / SchoolsManaging / VideoLinksManaging /
// ProfilePhotoManaging. If a given mock does not exist, create a minimal one
// alongside this test (mirroring MockPublicProfileManaging's style).

func testAssembleCardGatesOffAthleticWhenToggleFalse() async {
    let profileService = MockPublicProfileManaging()
    profileService.stubProfile = makeProfile()  // showAthletic=false in makeProfile()
    let vm = PublicProfileViewModel(
        service: profileService,
        authManager: MockAuthManager(),
        preferenceService: MockPreferenceManaging.withPlayerDetails(),
        schoolsService: MockSchoolsManaging.withSchools([("s1", "State U")]),
        videoLinksService: MockVideoLinksManaging.withLinks([("Highlights", "https://x/y")]),
        photoService: MockProfilePhotoManaging(photoUrl: nil),
        familyUnitId: "f1"
    )
    await vm.load()               // sets showAthletic = false
    await vm.assembleCard()
    XCTAssertNil(vm.cardData?.athletic)          // gated off
    XCTAssertNotNil(vm.cardData?.academics)      // showAcademics = true
    XCTAssertEqual(vm.cardData?.schools?.count, 1)
    XCTAssertEqual(vm.cardData?.film?.count, 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/PublicProfileViewModelTests/testAssembleCardGatesOffAthleticWhenToggleFalse`
Expected: FAIL — new init params / `assembleCard` / mocks not found.

- [ ] **Step 3: Write minimal implementation**

Extend the VM init to inject the four service protocols (default to concrete impls for production
call sites), add `cardData`, and implement `assembleCard()`:

```swift
func assembleCard() async {
    let uid = targetUserId ?? authManager.user?.id
    guard let uid else { return }

    async let details: PlayerDetails? = try? preferenceService.fetchPreferences(category: .player, userId: uid)
    async let photo: String? = try? photoService.currentPhotoURL(userId: uid)
    async let links = (try? videoLinksService.fetchVideoLinks(userId: uid)) ?? []
    async let schoolRows = (familyUnitId != nil ? (try? schoolsService.fetchSchools(familyUnitId: familyUnitId!)) : nil) ?? []

    let d = await details
    let name = (targetUserId == nil ? authManager.user?.fullName : nil) ?? d?.playerName ?? ""

    cardData = PublicProfileData(
        playerName: name,
        photoUrl: await photo,
        headerColor: headerColor,
        bio: bio.isEmpty ? nil : bio,
        academics: showAcademics ? academicsSection(from: d) : nil,
        athletic: showAthletic ? athleticSection(from: d) : nil,
        film: showFilm ? (await links).map { PublicProfileData.FilmItem(title: $0.title, url: $0.url) } : nil,
        schools: showSchools ? (await schoolRows).map { PublicProfileData.SchoolItem(id: $0.id, name: $0.name) } : nil
    )
}
```

Implement `academicsSection(from:)` / `athleticSection(from:)` mapping helpers against the real
`PlayerDetails` field names (read the file first). Use `d?.playerName` only if `PlayerDetails` has
a name field; otherwise drop that fallback.

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/ViewModels/PublicProfileViewModel.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/ViewModels/PublicProfileViewModelTests.swift
git commit -m "feat(public-profile): assemble native card data from existing services"
```

---

## Task 9: PublicProfileCard (native SwiftUI card)

**Files:**
- Reference (read for layout parity): `recruiting-compass-web/components/profile/PublicProfileCard.vue`.
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Views/PublicProfileCard.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Views/PublicProfileCardTests.swift`

**Interfaces:**
- Consumes: `PublicProfileData` (Task 3).
- Produces: `struct PublicProfileCard: View` with `let data: PublicProfileData`. Renders gradient header (from `data.headerColor.color`) with photo + name + sport/position + bio, then conditional Athletic / Academics / Film / Schools sections (each shown only when its `data.*` is non-nil), then a footer "Powered by The Recruiting Compass".

- [ ] **Step 1: Write the failing test** (logic-level: a small pure helper the view uses, so it's unit-testable without rendering)

```swift
import XCTest
@testable import TheRecruitingCompass

final class PublicProfileCardTests: XCTestCase {
    nonisolated deinit {}

    func testVisibleSectionsReflectNilData() {
        let data = PublicProfileData(
            playerName: "Jordan", photoUrl: nil, headerColor: .slate, bio: nil,
            academics: nil,
            athletic: .init(primarySport: "Baseball", primaryPosition: "SS",
                            positions: ["SS"], heightInches: 72, weightLbs: 180,
                            ncaaId: nil, perfectGameId: nil, prepBaseballId: nil),
            film: nil, schools: nil
        )
        let sections = PublicProfileCard.visibleSections(for: data)
        XCTAssertTrue(sections.contains(.athletic))
        XCTAssertFalse(sections.contains(.academics))
        XCTAssertFalse(sections.contains(.film))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/PublicProfileCardTests`
Expected: FAIL — `cannot find 'PublicProfileCard' in scope`.

- [ ] **Step 3: Write minimal implementation**

Build the card view. Extract a testable static `visibleSections(for:)`:

```swift
import SwiftUI

struct PublicProfileCard: View {
    let data: PublicProfileData

    enum Section: CaseIterable { case athletic, academics, film, schools }

    static func visibleSections(for data: PublicProfileData) -> Set<Section> {
        var s = Set<Section>()
        if data.athletic != nil { s.insert(.athletic) }
        if data.academics != nil { s.insert(.academics) }
        if data.film != nil { s.insert(.film) }
        if data.schools != nil { s.insert(.schools) }
        return s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let athletic = data.athletic { athleticSection(athletic) }
            if let academics = data.academics { academicsSection(academics) }
            if let film = data.film { filmSection(film) }
            if let schools = data.schools { schoolsSection(schools) }
            footer
        }
    }

    // header/section builders: use AsyncImage for photoUrl, semantic fonts
    // (.title/.headline/.body/.caption — never .system(size:)), AppColors,
    // and accessibility labels per project a11y rules. Gradient from
    // data.headerColor.color. Keep each section a private @ViewBuilder.
}
```

Fill in the private section builders with semantic fonts, `AsyncImage`, accessibility labels, and
a gradient header using `data.headerColor.color`. Match `PublicProfileCard.vue` section order and
fields. Keep the file ≤ ~300 lines; if it grows, split section builders into
`Components/PublicProfileSections.swift`.

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Views/PublicProfileCard.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Views/PublicProfileCardTests.swift
git commit -m "feat(public-profile): native SwiftUI coach-facing card"
```

---

## Task 10: HeaderColorPicker + ShareLinkRow components

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Components/HeaderColorPicker.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Components/ShareLinkRow.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Components/PublicProfileComponentsTests.swift`

**Interfaces:**
- Consumes: `HeaderColor`.
- Produces:
  - `struct HeaderColorPicker: View { @Binding var selection: HeaderColor }` — a horizontal swatch row of all 8 presets; tapping sets `selection`.
  - `struct ShareLinkRow: View { let url: URL?; var onCopy: () -> Void }` — displays the URL text (or an "unpublished" hint when `url == nil`) + a Copy button calling `onCopy`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class PublicProfileComponentsTests: XCTestCase {
    nonisolated deinit {}

    func testColorPickerInitializesWithBinding() {
        var selection = HeaderColor.slate
        let binding = Binding(get: { selection }, set: { selection = $0 })
        _ = HeaderColorPicker(selection: binding)  // compiles + constructs
        XCTAssertEqual(selection, .slate)
    }

    func testShareLinkRowCopyInvokesCallback() {
        var copied = false
        let row = ShareLinkRow(url: URL(string: "https://x/p/abc"), onCopy: { copied = true })
        row.onCopy()
        XCTAssertTrue(copied)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/PublicProfileComponentsTests`
Expected: FAIL — components not in scope.

- [ ] **Step 3: Write minimal implementation**

```swift
// HeaderColorPicker.swift
import SwiftUI

struct HeaderColorPicker: View {
    @Binding var selection: HeaderColor

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(HeaderColor.allCases, id: \.self) { color in
                    Circle()
                        .fill(color.color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle().strokeBorder(.primary, lineWidth: selection == color ? 3 : 0)
                        )
                        .onTapGesture { selection = color }
                        .accessibilityLabel(Text(color.label))
                        .accessibilityAddTraits(selection == color ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 4)
        }
    }
}
```

```swift
// ShareLinkRow.swift
import SwiftUI

struct ShareLinkRow: View {
    let url: URL?
    var onCopy: () -> Void

    var body: some View {
        HStack {
            if let url {
                Text(url.absoluteString)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(action: onCopy) {
                    Label(String(localized: "Copy"), systemImage: "doc.on.doc")
                }
                .accessibilityLabel(Text(String(localized: "Copy profile link")))
            } else {
                Text(String(localized: "Publish your profile to get a shareable link."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Components/ TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/Components/PublicProfileComponentsTests.swift
git commit -m "feat(public-profile): header color picker + share link row components"
```

---

## Task 11: PublicTab (editor + preview container)

**Files:**
- Reference (read): `Features/Preferences/Views/Tabs/BasicsTab.swift` (tab view shape, how it takes `viewModel: PlayerDetailsViewModel`).
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Views/PublicTab.swift`
- Test: none new (view composition; logic covered by VM tests). Build-verify only.

**Interfaces:**
- Consumes: `PublicProfileViewModel`, `PublicProfileCard`, `HeaderColorPicker`, `ShareLinkRow`, `PlayerDetailsViewModel` (for `targetUserId`/`familyUnitId` context).
- Produces: `struct PublicTab: View`. Constructs its own `@State private var vm: PublicProfileViewModel` (built from the shared `PlayerDetailsViewModel`'s context + concrete services), runs `.task { await vm.load(); await vm.assembleCard() }`, and re-assembles the card `.onChange` of each toggle/color/bio.

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct PublicTab: View {
    let viewModel: PlayerDetailsViewModel   // shared context (targetUserId, familyUnitId)
    @State private var vm: PublicProfileViewModel

    init(viewModel: PlayerDetailsViewModel) {
        self.viewModel = viewModel
        _vm = State(initialValue: PublicProfileViewModel(
            service: PublicProfileServiceImpl(),
            authManager: AuthManager.shared,
            preferenceService: PreferenceServiceImpl(),
            schoolsService: SchoolsServiceImpl(),
            videoLinksService: VideoLinksServiceImpl(),
            photoService: ProfilePhotoService(),
            targetUserId: viewModel.targetUserId,
            familyUnitId: viewModel.familyUnitId
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !vm.isConfigured {
                unconfiguredNotice
            } else {
                editor
                Divider()
                Text(String(localized: "What coaches see"))
                    .font(.headline)
                if let card = vm.cardData {
                    PublicProfileCard(data: card)
                }
            }
        }
        .padding(.horizontal)
        .task { await vm.load(); await vm.assembleCard() }
    }

    // editor: Toggle(is_published), ShareLinkRow(url: vm.shareURL, onCopy:),
    // vanity slug TextField + slugError, bio TextEditor + counter,
    // HeaderColorPicker($vm.headerColor), 4 section Toggles.
    // Each control's onChange/commit → Task { await vm.save(); await vm.assembleCard() }.
    // unconfiguredNotice: message pointing user to set up on web.
}
```

Fill the `editor` and `unconfiguredNotice` builders. Confirm the exact init names of the concrete
services (`PreferenceServiceImpl`, `SchoolsServiceImpl`, `VideoLinksServiceImpl`,
`ProfilePhotoService`) and that `PlayerDetailsViewModel` exposes `targetUserId` and a
`familyUnitId` — grep first; if `familyUnitId` isn't exposed, add a computed accessor to
`PlayerDetailsViewModel` or source it where Schools already reads it.

- [ ] **Step 2: Build-verify**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: exit 0, no new errors.

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/Views/PublicTab.swift
git commit -m "feat(public-profile): editor + preview tab container"
```

---

## Task 12: Wire 5th "Public" segment into PlayerDetailsView

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/PlayerDetailsView.swift` (titles array ~14-19; `tabContent` switch ~73-81)
- Test: none new (integration exercised at build + manual). Build-verify.

**Interfaces:**
- Consumes: `PublicTab` (Task 11).

- [ ] **Step 1: Add the tab title**

Edit the `tabTitles` array to append a 5th entry:

```swift
private static let tabTitles = [
    String(localized: "Basics"),
    String(localized: "Athletics"),
    String(localized: "Academics"),
    String(localized: "History"),
    String(localized: "Public")
]
```

- [ ] **Step 2: Add the switch case**

Edit `tabContent`:

```swift
@ViewBuilder
private var tabContent: some View {
    switch viewModel.selectedTab {
    case 1:  AthleticsTab(viewModel: viewModel)
    case 2:  AcademicsSocialTab(viewModel: viewModel)
    case 3:  HistoryTab(viewModel: viewModel)
    case 4:  PublicTab(viewModel: viewModel)
    default: BasicsTab(viewModel: viewModel)
    }
}
```

- [ ] **Step 3: Build-verify + visual check**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: exit 0.

Manual: launch app, open Player Profile, confirm 5 segments render and "Public" loads the editor.
If 5 segments crowd on narrow width (iPhone SE), note it — a follow-up may switch the segmented
Picker to a menu/scrollable style. Not a blocker for this task.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/PlayerDetailsView.swift
git commit -m "feat(public-profile): add Public segment to player details"
```

---

## Task 13: Send Profile on coach detail

**Files:**
- Reference (read): `recruiting-compass-web/components/coaches/CoachProfileLink.vue` (behavior parity) and `pages/coaches/[id].vue` (placement). In iOS, find the coach detail view: `grep -rln "CoachDetail\|coach detail" TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views`.
- Modify: the iOS coach detail view (path found via grep) — add a "Send Profile" button.
- Create (if needed): `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/ViewModels/SendProfileViewModel.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/ViewModels/SendProfileViewModelTests.swift`

**Interfaces:**
- Consumes: `PublicProfileManaging` (`createTrackingLink`, `fetchProfile` for the slug), `AuthManaging`.
- Produces: `@Observable @MainActor final class SendProfileViewModel` with:
  - init `(service: PublicProfileManaging, authManager: AuthManaging)`
  - `func shareURL(forCoachId: String) async -> URL?` — ensures a profile exists + is published, POSTs a tracking link, returns `…/p/<slug>?ref=<refToken>` (nil if no profile / unpublished / unconfigured)
  - `var notPublishedPrompt: Bool` (set when profile exists but `is_published == false`)

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SendProfileViewModelTests: XCTestCase {
    nonisolated deinit {}

    func testShareURLIncludesRefToken() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = PlayerProfile(
            id: "p1", userId: "u1", familyUnitId: "f1", hashSlug: "ab12cd",
            vanitySlug: "jordan", isPublished: true, bio: nil, headerColor: "slate",
            showAcademics: true, showAthletic: true, showFilm: true, showSchools: true,
            createdAt: "", updatedAt: ""
        )
        mock.stubTrackingLink = ProfileTrackingLink(
            id: "t1", profileId: "p1", coachId: "c1", refToken: "abcd1234",
            viewCount: 0, lastViewedAt: nil, createdAt: ""
        )
        let vm = SendProfileViewModel(service: mock, authManager: MockAuthManager())
        let url = await vm.shareURL(forCoachId: "c1")
        XCTAssertEqual(url?.absoluteString.contains("/p/jordan"), true)
        XCTAssertEqual(url?.absoluteString.contains("ref=abcd1234"), true)
        XCTAssertEqual(mock.createdCoachIds, ["c1"])
    }

    func testUnpublishedProfileSetsPrompt() async {
        let mock = MockPublicProfileManaging()
        mock.stubProfile = PlayerProfile(
            id: "p1", userId: "u1", familyUnitId: "f1", hashSlug: "ab12cd",
            vanitySlug: nil, isPublished: false, bio: nil, headerColor: "slate",
            showAcademics: true, showAthletic: true, showFilm: true, showSchools: true,
            createdAt: "", updatedAt: ""
        )
        let vm = SendProfileViewModel(service: mock, authManager: MockAuthManager())
        let url = await vm.shareURL(forCoachId: "c1")
        XCTAssertNil(url)
        XCTAssertTrue(vm.notPublishedPrompt)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/SendProfileViewModelTests`
Expected: FAIL — `cannot find 'SendProfileViewModel'`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class SendProfileViewModel {
    nonisolated deinit {}

    private let service: PublicProfileManaging
    private let authManager: AuthManaging
    var notPublishedPrompt = false

    init(service: PublicProfileManaging, authManager: AuthManaging) {
        self.service = service
        self.authManager = authManager
    }

    func shareURL(forCoachId coachId: String) async -> URL? {
        notPublishedPrompt = false
        let token = authManager.session?.accessToken
        guard let profile = try? await service.fetchProfile(accessToken: token) else { return nil }
        guard profile.isPublished else { notPublishedPrompt = true; return nil }
        guard let link = try? await service.createTrackingLink(coachId: coachId, accessToken: token) else { return nil }
        guard let base = SupabaseConfig.apiBaseURL else { return nil }
        let slug = profile.vanitySlug?.isEmpty == false ? profile.vanitySlug! : profile.hashSlug
        var comps = URLComponents(url: base.appendingPathComponent("p").appendingPathComponent(slug),
                                  resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "ref", value: link.refToken)]
        return comps?.url
    }
}
```

Then add a "Send Profile" button to the coach detail view that calls `shareURL(forCoachId:)` and
presents a share sheet (`ShareLink(item: url)` when non-nil, else an alert prompting the user to
publish, driven by `notPublishedPrompt`). Match the placement of other coach-detail actions.

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (2 tests).

- [ ] **Step 5: Build-verify + commit**

```bash
cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
cd ..
git add TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/ViewModels/SendProfileViewModel.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/PublicProfile/ViewModels/SendProfileViewModelTests.swift <coach-detail-view-path>
git commit -m "feat(public-profile): Send Profile tracking link on coach detail"
```

---

## Task 14: Full-suite verification + SwiftLint

**Files:** none (verification only).

- [ ] **Step 1: Build clean**

Run: `cd TheRecruitingCompass && xcodebuild clean build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: exit 0, no new errors/warnings from PublicProfile files.

- [ ] **Step 2: Run the feature test classes**

Run:
```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/PlayerProfileTests \
  -only-testing:TheRecruitingCompassTests/HeaderColorTests \
  -only-testing:TheRecruitingCompassTests/PublicProfileDataTests \
  -only-testing:TheRecruitingCompassTests/MockPublicProfileManagingTests \
  -only-testing:TheRecruitingCompassTests/PublicProfileServiceImplTests \
  -only-testing:TheRecruitingCompassTests/SlugValidatorTests \
  -only-testing:TheRecruitingCompassTests/PublicProfileViewModelTests \
  -only-testing:TheRecruitingCompassTests/PublicProfileCardTests \
  -only-testing:TheRecruitingCompassTests/PublicProfileComponentsTests \
  -only-testing:TheRecruitingCompassTests/SendProfileViewModelTests
```
Expected: all pass (trust xcodebuild exit code + passed/failed counts, not a "TEST SUCCEEDED" grep).

- [ ] **Step 3: Lint**

Run: `swiftlint --config .swiftlint.yml --path TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile`
Expected: no line_length (≤120) or identifier_name violations in new files. Fix any.

- [ ] **Step 4: Final commit if lint fixes were needed**

```bash
git add -A TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile
git commit -m "chore(public-profile): lint cleanup"
```

---

## Self-Review Notes (author)

- **Spec coverage:** editor (T7, T11), share link (T7 shareURL, T10 ShareLinkRow), vanity slug + validation (T6, T7), bio/header/section toggles (T7, T10), native card (T3, T8, T9), Send Profile tracking (T13), reuse-web-API + CSRF + graceful degrade (T5), 5th segment (T12), video_links reuse (T8), skip analytics (no task — intentional). All spec sections mapped.
- **Deferred verifications flagged inline** (not placeholders — real "read the actual file" steps the implementer must do): `Color(hex:)` existence (T2), `apiBaseURL` under test env (T5), `AuthManaging` session/refresh names (T7), `PlayerDetails` field names (T8), concrete service init names + `familyUnitId` exposure (T11), coach detail view path (T13). Each has a grep instruction.
- **Type consistency:** `PublicProfileManaging` signatures identical across T4/T5/T7/T13; `UpdateProfilePayload` double-optional contract consistent T1/T7; `PublicProfileData` nested types consistent T3/T8/T9.
- **Known risk carried from spec:** 5-segment crowding (T12 manual check, non-blocking).
