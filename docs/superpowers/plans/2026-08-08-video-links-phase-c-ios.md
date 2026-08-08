# Video Links — Phase C (iOS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give iOS a real video-links feature — a `VideoLink` model + Supabase CRUD service, a player-details settings editor (player-writes / parents view-only, max 5, health badge), an extension of the existing action-item CTA router so `add_video`/`update_video` suggestions open that editor, and a coach-comms template variable for film links — all against the canonical `video_links` table shipped in Phase A.

**Architecture:** Extends the existing `feature/action-item-buttons` branch (Path A already built the CTA card, sheet-presentation pattern, and the `ActionItemCTA` enum that explicitly left video as a gap). We mirror established feature shapes: service like `DocumentsServiceImpl`, form VM like `AddInteractionViewModel`, settings entry like `communicationTemplates`, comms variable like the existing `TemplateVariable.all` entries. No new top-level tab; the editor is a `SettingsDestination` reachable both from Settings and from the action-item CTA sheet.

**Tech Stack:** Swift 6 / SwiftUI, `@Observable @MainActor` view models, `supabase-swift` (`SupabaseManager.shared.client`), XCTest. Source is DOUBLE-NESTED under `TheRecruitingCompass/TheRecruitingCompass/`; tests under `TheRecruitingCompass/TheRecruitingCompassTests/`.

## Global Constraints

- **Branch:** work on `feature/action-item-buttons` (Phase C folds in, NOT a separate branch). Commit there.
- **Paths are DOUBLE-NESTED:** source files live at `TheRecruitingCompass/TheRecruitingCompass/Features/...`; tests at `TheRecruitingCompass/TheRecruitingCompassTests/Features/...`. Never the single-nested path. Xcode uses `PBXFileSystemSynchronizedRootGroup` — new `.swift` files are auto-included; NEVER edit `.xcodeproj` or run `add_files_to_xcode.rb`.
- **`video_links` table contract (Phase A, authoritative — do not drift):** columns `id`(uuid), `user_id`(uuid, the PLAYER/owner), `family_unit_id`(uuid, nullable — parent read access), `platform`(text CHECK `hudl|youtube|vimeo`), `url`(text), `title`(text nullable), `position`(int, 0..4), `health_status`(text CHECK `healthy|broken|unknown`, default `unknown`), `last_health_check`(timestamptz nullable), `created_at`, `updated_at`. Max 5 rows/user (DB trigger backstop; app enforces UX-side). RLS: owner-or-family SELECT; owning-player INSERT/UPDATE/DELETE (parents blocked at DB).
- **Localization:** every user-facing string wrapped in `String(localized:)`.
- **macOS 26.x deinit workaround:** every `@MainActor` class (production AND `@MainActor XCTestCase`) must declare `nonisolated deinit {}`. Plain (non-`@MainActor`) services do NOT get it — mirror `DocumentsServiceImpl` (no deinit) vs `AddInteractionViewModel` (has `nonisolated deinit {}`).
- **Services are `Sendable`, not `@MainActor`; ViewModels are `@Observable @MainActor`.** Protocol-based DI: every service has a protocol + a mock for VM tests.
- **Athlete-ownership resolution (canonical, live at `DocumentsListViewModel.swift:177`):** `familyManager.selectedAthlete?.userId ?? authManager.user?.id`.
- **Player-vs-parent guard:** `familyManager.currentMember?.isParent == true` → read-only (hide/disable add/edit/delete).
- **Build/test (run from `TheRecruitingCompass/` wrapper dir, NOT repo root):**
  ```bash
  cd TheRecruitingCompass
  xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'
  xcodebuild test  -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/Features/VideoLinks
  ```
  Trust `xcodebuild` exit code, not a "TEST SUCCEEDED" grep. Run affected test classes for fast evidence; full unit target (~3700) exceeds one 10-min window.

---

### Task 1: `VideoLink` model + platform/health enums

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/VideoLinks/Models/VideoLink.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/VideoLinks/VideoLinkModelTests.swift`

**Interfaces:**
- Produces: `struct VideoLink: Codable, Identifiable, Sendable, Equatable` with fields `id: String`, `userId: String`, `familyUnitId: String?`, `platform: VideoLinkPlatform`, `url: String`, `title: String?`, `position: Int`, `healthStatus: VideoLinkHealth`, `lastHealthCheck: Date?`, `createdAt: Date?`, `updatedAt: Date?`. Enums `VideoLinkPlatform: String, Codable` (`hudl|youtube|vimeo`) and `VideoLinkHealth: String, Codable` (`healthy|broken|unknown`), each with an unknown-fallback decode and a `displayName`. Consumed by every later task.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Features/VideoLinks/VideoLinkModelTests.swift
import XCTest
@testable import TheRecruitingCompass

final class VideoLinkModelTests: XCTestCase {
  private func decode(_ json: String) throws -> VideoLink {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return try d.decode(VideoLink.self, from: Data(json.utf8))
  }

  func test_decodesSnakeCaseRow() throws {
    let link = try decode("""
    {"id":"v1","user_id":"u1","family_unit_id":"f1","platform":"hudl",
     "url":"https://hudl.com/x","title":"Fall reel","position":0,
     "health_status":"healthy","last_health_check":null,
     "created_at":null,"updated_at":null}
    """)
    XCTAssertEqual(link.id, "v1")
    XCTAssertEqual(link.userId, "u1")
    XCTAssertEqual(link.familyUnitId, "f1")
    XCTAssertEqual(link.platform, .hudl)
    XCTAssertEqual(link.healthStatus, .healthy)
    XCTAssertEqual(link.position, 0)
  }

  func test_unknownPlatformAndHealthFallBack() throws {
    let link = try decode("""
    {"id":"v2","user_id":"u1","family_unit_id":null,"platform":"tiktok",
     "url":"https://x","title":null,"position":1,"health_status":"weird",
     "last_health_check":null,"created_at":null,"updated_at":null}
    """)
    XCTAssertEqual(link.platform, .unknown)
    XCTAssertEqual(link.healthStatus, .unknown)
    XCTAssertNil(link.title)
    XCTAssertNil(link.familyUnitId)
  }
}
```

- [ ] **Step 2: Run — expect fail**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/VideoLinkModelTests`
Expected: FAIL — `VideoLink` undefined / no such type in scope (or a clean build failure).

- [ ] **Step 3: Implement**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Features/VideoLinks/Models/VideoLink.swift
import Foundation

enum VideoLinkPlatform: String, Codable, Sendable, CaseIterable {
  case hudl, youtube, vimeo, unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = VideoLinkPlatform(rawValue: raw) ?? .unknown
  }

  var displayName: String {
    switch self {
    case .hudl: return String(localized: "Hudl")
    case .youtube: return String(localized: "YouTube")
    case .vimeo: return String(localized: "Vimeo")
    case .unknown: return String(localized: "Other")
    }
  }

  /// Platforms a user may pick when creating a link (excludes `.unknown`).
  static var selectable: [VideoLinkPlatform] { [.hudl, .youtube, .vimeo] }
}

enum VideoLinkHealth: String, Codable, Sendable {
  case healthy, broken, unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = VideoLinkHealth(rawValue: raw) ?? .unknown
  }

  var displayName: String {
    switch self {
    case .healthy: return String(localized: "Working")
    case .broken: return String(localized: "Broken link")
    case .unknown: return String(localized: "Not checked")
    }
  }
}

struct VideoLink: Codable, Identifiable, Sendable, Equatable {
  let id: String
  let userId: String
  let familyUnitId: String?
  let platform: VideoLinkPlatform
  let url: String
  let title: String?
  let position: Int
  let healthStatus: VideoLinkHealth
  let lastHealthCheck: Date?
  let createdAt: Date?
  let updatedAt: Date?

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
    case platform, url, title, position
    case healthStatus = "health_status"
    case lastHealthCheck = "last_health_check"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}
```

- [ ] **Step 4: Run — expect pass** (same command as Step 2).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/VideoLinks/Models/VideoLink.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/VideoLinks/VideoLinkModelTests.swift
git commit -m "feat(ios): VideoLink model + platform/health enums (video_links table shape)"
```

---

### Task 2: `VideoLinksManaging` protocol + service + mock

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/VideoLinks/Services/VideoLinksManaging.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/VideoLinks/Services/VideoLinksServiceImpl.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompassTests/Features/VideoLinks/MockVideoLinksService.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/VideoLinks/VideoLinksServiceContractTests.swift`

**Interfaces:**
- Consumes: `VideoLink` (Task 1), `SupabaseManager.shared.client`.
- Produces:
  ```swift
  struct VideoLinkCreateRequest: Sendable {
    let userId: String; let familyUnitId: String?
    let platform: VideoLinkPlatform; let url: String
    let title: String?; let position: Int
  }
  struct VideoLinkUpdateRequest: Sendable {
    let platform: VideoLinkPlatform?; let url: String?
    let title: String?; let position: Int?
  }
  protocol VideoLinksManaging: Sendable {
    func fetchVideoLinks(userId: String) async throws -> [VideoLink]
    func createVideoLink(_ request: VideoLinkCreateRequest) async throws -> VideoLink
    func updateVideoLink(id: String, userId: String, _ request: VideoLinkUpdateRequest) async throws -> VideoLink
    func deleteVideoLink(id: String, userId: String) async throws
  }
  ```
  Plus `final class MockVideoLinksService: VideoLinksManaging, @unchecked Sendable` (test target) used by Task 3's VM tests. `VideoLinksServiceImpl` mirrors `DocumentsServiceImpl` exactly (plain `final class ... Sendable`, `private let supabaseManager`, no `nonisolated deinit`).

> **Design note — test scope.** A thin Supabase service has no meaningful pure-unit test (a real client needs a live backend; that path is covered by integration/E2E). The unit coverage that matters — max-5, player-only, list/add/delete round-trips — lands in Task 3 via `MockVideoLinksService`. This task's test asserts only the mock's contract behavior (so later tasks can trust it) and that the request/update structs carry the right fields.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Features/VideoLinks/VideoLinksServiceContractTests.swift
import XCTest
@testable import TheRecruitingCompass

final class VideoLinksServiceContractTests: XCTestCase {
  func test_mockCreateAppendsAndFetchReturns() async throws {
    let mock = MockVideoLinksService()
    let req = VideoLinkCreateRequest(userId: "u1", familyUnitId: "f1",
                                     platform: .hudl, url: "https://hudl.com/x",
                                     title: "Reel", position: 0)
    let created = try await mock.createVideoLink(req)
    XCTAssertEqual(created.userId, "u1")
    XCTAssertEqual(created.platform, .hudl)
    let all = try await mock.fetchVideoLinks(userId: "u1")
    XCTAssertEqual(all.count, 1)
    XCTAssertEqual(all.first?.url, "https://hudl.com/x")
  }

  func test_mockDeleteRemoves() async throws {
    let mock = MockVideoLinksService()
    let created = try await mock.createVideoLink(
      .init(userId: "u1", familyUnitId: nil, platform: .vimeo,
            url: "https://v", title: nil, position: 0))
    try await mock.deleteVideoLink(id: created.id, userId: "u1")
    let all = try await mock.fetchVideoLinks(userId: "u1")
    XCTAssertTrue(all.isEmpty)
  }
}
```

- [ ] **Step 2: Run — expect fail** (`MockVideoLinksService` / `VideoLinkCreateRequest` undefined).

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/VideoLinksServiceContractTests`

- [ ] **Step 3: Implement**

`VideoLinksManaging.swift` — the request structs + protocol from Interfaces above (copy verbatim).

`VideoLinksServiceImpl.swift` (mirror `DocumentsServiceImpl.swift:44-64,234-273`):
```swift
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "VideoLinksService")

private struct VideoLinkInsertPayload: Encodable {
  let userId: String; let familyUnitId: String?
  let platform: String; let url: String; let title: String?; let position: Int
  enum CodingKeys: String, CodingKey {
    case userId = "user_id"; case familyUnitId = "family_unit_id"
    case platform, url, title, position
  }
}
private struct VideoLinkUpdatePayload: Encodable {
  let platform: String?; let url: String?; let title: String?; let position: Int?
}

final class VideoLinksServiceImpl: VideoLinksManaging, Sendable {
  private let supabaseManager: SupabaseManager
  init(supabaseManager: SupabaseManager = .shared) { self.supabaseManager = supabaseManager }

  func fetchVideoLinks(userId: String) async throws -> [VideoLink] {
    logger.debug("Fetching video links for user: \(userId)")
    let links: [VideoLink] = try await supabaseManager.client
      .from("video_links")
      .select()
      .eq("user_id", value: userId)
      .order("position", ascending: true)
      .execute()
      .value
    logger.info("Fetched \(links.count) video links")
    return links
  }

  func createVideoLink(_ request: VideoLinkCreateRequest) async throws -> VideoLink {
    let payload = VideoLinkInsertPayload(
      userId: request.userId, familyUnitId: request.familyUnitId,
      platform: request.platform.rawValue, url: request.url,
      title: request.title, position: request.position)
    let link: VideoLink = try await supabaseManager.client
      .from("video_links").insert(payload).select().single().execute().value
    return link
  }

  func updateVideoLink(id: String, userId: String, _ request: VideoLinkUpdateRequest) async throws -> VideoLink {
    let payload = VideoLinkUpdatePayload(
      platform: request.platform?.rawValue, url: request.url,
      title: request.title, position: request.position)
    let link: VideoLink = try await supabaseManager.client
      .from("video_links").update(payload)
      .eq("id", value: id).eq("user_id", value: userId)
      .select().single().execute().value
    return link
  }

  func deleteVideoLink(id: String, userId: String) async throws {
    try await supabaseManager.client
      .from("video_links").delete()
      .eq("id", value: id).eq("user_id", value: userId)
      .execute()
  }
}
```
> Note: `title` in the update payload is always sent (nil clears it). If a partial-update-without-clobbering-title case emerges later, split into an explicit-fields encoder — out of scope now; the editor always sends the full row.

`MockVideoLinksService.swift` (test target):
```swift
import Foundation
@testable import TheRecruitingCompass

final class MockVideoLinksService: VideoLinksManaging, @unchecked Sendable {
  var links: [VideoLink] = []
  var createError: Error?
  var fetchError: Error?

  func fetchVideoLinks(userId: String) async throws -> [VideoLink] {
    if let fetchError { throw fetchError }
    return links.filter { $0.userId == userId }.sorted { $0.position < $1.position }
  }
  func createVideoLink(_ r: VideoLinkCreateRequest) async throws -> VideoLink {
    if let createError { throw createError }
    let link = VideoLink(id: UUID().uuidString, userId: r.userId, familyUnitId: r.familyUnitId,
      platform: r.platform, url: r.url, title: r.title, position: r.position,
      healthStatus: .unknown, lastHealthCheck: nil, createdAt: nil, updatedAt: nil)
    links.append(link); return link
  }
  func updateVideoLink(id: String, userId: String, _ r: VideoLinkUpdateRequest) async throws -> VideoLink {
    guard let i = links.firstIndex(where: { $0.id == id && $0.userId == userId }) else {
      throw NSError(domain: "MockVideoLinks", code: 404)
    }
    let e = links[i]
    let updated = VideoLink(id: e.id, userId: e.userId, familyUnitId: e.familyUnitId,
      platform: r.platform ?? e.platform, url: r.url ?? e.url,
      title: r.title ?? e.title, position: r.position ?? e.position,
      healthStatus: e.healthStatus, lastHealthCheck: e.lastHealthCheck,
      createdAt: e.createdAt, updatedAt: e.updatedAt)
    links[i] = updated; return updated
  }
  func deleteVideoLink(id: String, userId: String) async throws {
    links.removeAll { $0.id == id && $0.userId == userId }
  }
}
```

- [ ] **Step 4: Run — expect pass** (same command as Step 2).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/VideoLinks/Services/ \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/VideoLinks/MockVideoLinksService.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/VideoLinks/VideoLinksServiceContractTests.swift
git commit -m "feat(ios): VideoLinksManaging protocol + Supabase service + mock"
```

---

### Task 3: `VideoLinksEditorViewModel` (load / add / update / delete, max-5, parent read-only)

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/VideoLinks/ViewModels/VideoLinksEditorViewModel.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/VideoLinks/VideoLinksEditorViewModelTests.swift`

**Interfaces:**
- Consumes: `VideoLinksManaging`, `VideoLinkCreateRequest`, `VideoLinkUpdateRequest`, `VideoLink` (Task 2/1).
- Produces: `@Observable @MainActor final class VideoLinksEditorViewModel` with `nonisolated deinit {}`; `var links: [VideoLink]`, `var isLoading`, `var isSubmitting`, `var errorMessage: String?`; `let isReadOnly: Bool` (parent); `let maxLinks = 5`; computed `var canAddLink: Bool { !isReadOnly && links.count < maxLinks }`; methods `func load() async`, `func addLink(platform:url:title:) async -> Bool`, `func updateLink(id:platform:url:title:) async -> Bool`, `func deleteLink(id:) async -> Bool`. Consumed by Task 4's views.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Features/VideoLinks/VideoLinksEditorViewModelTests.swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class VideoLinksEditorViewModelTests: XCTestCase {
  nonisolated deinit {}

  private func makeVM(readOnly: Bool = false, seed: [VideoLink] = []) -> (VideoLinksEditorViewModel, MockVideoLinksService) {
    let mock = MockVideoLinksService(); mock.links = seed
    let vm = VideoLinksEditorViewModel(service: mock, athleteUserId: "u1",
                                       familyUnitId: "f1", isReadOnly: readOnly)
    return (vm, mock)
  }
  private func link(_ id: String, _ pos: Int) -> VideoLink {
    VideoLink(id: id, userId: "u1", familyUnitId: "f1", platform: .hudl,
      url: "https://hudl.com/\(id)", title: nil, position: pos,
      healthStatus: .unknown, lastHealthCheck: nil, createdAt: nil, updatedAt: nil)
  }

  func test_loadPopulatesLinks() async {
    let (vm, _) = makeVM(seed: [link("a", 0), link("b", 1)])
    await vm.load()
    XCTAssertEqual(vm.links.count, 2)
    XCTAssertFalse(vm.isLoading)
  }

  func test_addAppendsAndDefaultsPositionToCount() async {
    let (vm, _) = makeVM(seed: [link("a", 0)])
    await vm.load()
    let ok = await vm.addLink(platform: .youtube, url: "https://youtu.be/x", title: "New")
    XCTAssertTrue(ok)
    XCTAssertEqual(vm.links.count, 2)
    XCTAssertEqual(vm.links.last?.position, 1)
  }

  func test_addBlockedAtMaxFive() async {
    let (vm, _) = makeVM(seed: (0..<5).map { link("l\($0)", $0) })
    await vm.load()
    XCTAssertFalse(vm.canAddLink)
    let ok = await vm.addLink(platform: .hudl, url: "https://hudl.com/six", title: nil)
    XCTAssertFalse(ok)
    XCTAssertEqual(vm.links.count, 5)
    XCTAssertNotNil(vm.errorMessage)
  }

  func test_readOnlyParentCannotAddOrDelete() async {
    let (vm, _) = makeVM(readOnly: true, seed: [link("a", 0)])
    await vm.load()
    XCTAssertFalse(vm.canAddLink)
    let added = await vm.addLink(platform: .hudl, url: "https://x", title: nil)
    XCTAssertFalse(added)
    let deleted = await vm.deleteLink(id: "a")
    XCTAssertFalse(deleted)
    XCTAssertEqual(vm.links.count, 1)
  }

  func test_deleteRemoves() async {
    let (vm, _) = makeVM(seed: [link("a", 0), link("b", 1)])
    await vm.load()
    let ok = await vm.deleteLink(id: "a")
    XCTAssertTrue(ok)
    XCTAssertEqual(vm.links.map(\.id), ["b"])
  }
}
```

- [ ] **Step 2: Run — expect fail** (VM undefined).

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/VideoLinksEditorViewModelTests`

- [ ] **Step 3: Implement**

```swift
// TheRecruitingCompass/TheRecruitingCompass/Features/VideoLinks/ViewModels/VideoLinksEditorViewModel.swift
import Foundation

@Observable
@MainActor
final class VideoLinksEditorViewModel {
  nonisolated deinit {}

  var links: [VideoLink] = []
  var isLoading = false
  var isSubmitting = false
  var errorMessage: String?

  var isShowingErrorAlert: Bool {
    get { errorMessage != nil }
    set { if !newValue { errorMessage = nil } }
  }

  let isReadOnly: Bool
  let maxLinks = 5
  var canAddLink: Bool { !isReadOnly && links.count < maxLinks }

  private let service: any VideoLinksManaging
  private let athleteUserId: String
  private let familyUnitId: String?

  init(service: any VideoLinksManaging, athleteUserId: String,
       familyUnitId: String?, isReadOnly: Bool) {
    self.service = service
    self.athleteUserId = athleteUserId
    self.familyUnitId = familyUnitId
    self.isReadOnly = isReadOnly
  }

  func load() async {
    isLoading = true; defer { isLoading = false }
    do { links = try await service.fetchVideoLinks(userId: athleteUserId) }
    catch { errorMessage = String(localized: "Couldn't load video links. Please try again.") }
  }

  func addLink(platform: VideoLinkPlatform, url: String, title: String?) async -> Bool {
    guard canAddLink else {
      errorMessage = isReadOnly
        ? String(localized: "Only the player can edit video links.")
        : String(localized: "You can add up to 5 video links.")
      return false
    }
    isSubmitting = true; defer { isSubmitting = false }
    do {
      let created = try await service.createVideoLink(.init(
        userId: athleteUserId, familyUnitId: familyUnitId,
        platform: platform, url: url,
        title: title?.isEmpty == true ? nil : title, position: links.count))
      links.append(created)
      return true
    } catch {
      errorMessage = String(localized: "Couldn't save the video link. Please try again.")
      return false
    }
  }

  func updateLink(id: String, platform: VideoLinkPlatform, url: String, title: String?) async -> Bool {
    guard !isReadOnly else {
      errorMessage = String(localized: "Only the player can edit video links.")
      return false
    }
    isSubmitting = true; defer { isSubmitting = false }
    do {
      let updated = try await service.updateVideoLink(id: id, userId: athleteUserId, .init(
        platform: platform, url: url, title: title?.isEmpty == true ? nil : title, position: nil))
      if let i = links.firstIndex(where: { $0.id == id }) { links[i] = updated }
      return true
    } catch {
      errorMessage = String(localized: "Couldn't update the video link. Please try again.")
      return false
    }
  }

  func deleteLink(id: String) async -> Bool {
    guard !isReadOnly else { return false }
    isSubmitting = true; defer { isSubmitting = false }
    do {
      try await service.deleteVideoLink(id: id, userId: athleteUserId)
      links.removeAll { $0.id == id }
      return true
    } catch {
      errorMessage = String(localized: "Couldn't delete the video link. Please try again.")
      return false
    }
  }
}
```

- [ ] **Step 4: Run — expect pass** (same command as Step 2).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/VideoLinks/ViewModels/VideoLinksEditorViewModel.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/VideoLinks/VideoLinksEditorViewModelTests.swift
git commit -m "feat(ios): video-links editor VM (load/add/update/delete, max-5, parent read-only)"
```

---

### Task 4: Editor views + Settings entry

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/VideoLinks/Views/VideoLinksEditorView.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/VideoLinks/Views/AddEditVideoLinkView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Settings/Views/SettingsView.swift` (add `SettingsDestination.videoLinks` case ~line 7; a `NavigationLink(value:)` row in the Profile & Player Info section ~lines 95-106; a `.navigationDestination` switch arm ~lines 213-217)
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/VideoLinks/VideoLinksEditorViewTests.swift`

**Interfaces:**
- Consumes: `VideoLinksEditorViewModel` (Task 3), `AuthManager`, `FamilyManager`, `VideoLinkPlatform`.
- Produces: `VideoLinksEditorView` (host-agnostic — works pushed in Settings AND wrapped in the CTA sheet's `NavigationStack`, Task 5). It constructs its VM from `authManager`/`familyManager` (athlete id + family + parent flag). `AddEditVideoLinkView` is the add/edit form (platform `Picker`, url + title `TextField`, Save). Exposes `VideoLinksEditorView(athleteUserId:familyUnitId:isReadOnly:service:)` for tests/hosts to inject.

**Design note:** the editor derives its inputs from the environment managers at the Settings call site — `athleteUserId = familyManager.selectedAthlete?.userId ?? authManager.user?.id ?? ""`, `familyUnitId = familyManager.currentMember?.familyUnitId`, `isReadOnly = familyManager.currentMember?.isParent == true`. Provide an init that takes them explicitly (so the CTA sheet and tests inject) plus a convenience that reads the managers.

- [ ] **Step 1: Write the failing test**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Features/VideoLinks/VideoLinksEditorViewTests.swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class VideoLinksEditorViewTests: XCTestCase {
  nonisolated deinit {}

  func test_readOnlyHidesAddButton() {
    let view = VideoLinksEditorView(athleteUserId: "u1", familyUnitId: "f1",
                                    isReadOnly: true, service: MockVideoLinksService())
    XCTAssertFalse(view.showsAddButton)  // computed: !viewModel.isReadOnly
  }

  func test_playerShowsAddButton() {
    let view = VideoLinksEditorView(athleteUserId: "u1", familyUnitId: "f1",
                                    isReadOnly: false, service: MockVideoLinksService())
    XCTAssertTrue(view.showsAddButton)
  }
}
```

> This asserts a small internal computed property (the codebase's established unit-test-a-SwiftUI-View pattern per memory: expose an internal `var` and read it, rather than walking the UIHostingController tree). Keep view logic behind such readable properties.

- [ ] **Step 2: Run — expect fail** (`VideoLinksEditorView` undefined / `showsAddButton` missing).

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/VideoLinksEditorViewTests`

- [ ] **Step 3: Implement**

`VideoLinksEditorView.swift` — a `List` of links (title/url/platform + a health badge `Label(link.healthStatus.displayName, ...)` tinted by health), a toolbar "Add" button gated on `viewModel.canAddLink`, swipe-to-delete gated on `!viewModel.isReadOnly`, `.sheet` presenting `AddEditVideoLinkView` for add/edit, `.task { await viewModel.load() }`, `.alert(... isShowingErrorAlert)`. Expose `var showsAddButton: Bool { !viewModel.isReadOnly }` (internal, for the test). Provide:
```swift
init(athleteUserId: String, familyUnitId: String?, isReadOnly: Bool,
     service: any VideoLinksManaging = VideoLinksServiceImpl()) {
  _viewModel = State(initialValue: VideoLinksEditorViewModel(
    service: service, athleteUserId: athleteUserId,
    familyUnitId: familyUnitId, isReadOnly: isReadOnly))
}
```
and a convenience `init(authManager:familyManager:)` (or resolve at the Settings call site — either is fine, keep one). Health badge colors: `.healthy` green, `.broken` red, `.unknown` secondary. Empty state: a message + (players only) an inline "Add your first video link".

`AddEditVideoLinkView.swift` — a `Form` with a `Picker("Platform", selection:)` over `VideoLinkPlatform.selectable` (`.displayName`), a `TextField` for URL (`.keyboardType(.URL)`, `.textInputAutocapitalization(.never)`), a `TextField` for optional title, a Save button disabled until the URL is non-empty and parses (`URL(string:)` non-nil / has a scheme), Cancel in toolbar. On Save → `await viewModel.addLink(...)` (or `updateLink` in edit mode); dismiss on `true`. Mirror `AddInteractionView`'s `@Environment(\.dismiss)` + Task-wrapped submit.

`SettingsView.swift` edits:
```swift
// enum SettingsDestination (~line 7): add
case videoLinks
// Profile & Player Info section (~after the playerDetails NavigationLink, ~line 103):
NavigationLink(value: SettingsDestination.videoLinks) {
  SettingsRow(icon: "play.rectangle.fill",
              title: String(localized: "Video Links"),
              description: String(localized: "Highlight and film links coaches can watch"),
              color: .blue, badgeStatus: nil)
}
// .navigationDestination switch (~line 213-217): add
case .videoLinks:
  VideoLinksEditorView(
    athleteUserId: familyManager.selectedAthlete?.userId ?? authManager.user?.id ?? "",
    familyUnitId: familyManager.currentMember?.familyUnitId,
    isReadOnly: familyManager.currentMember?.isParent == true)
```
Verify `familyManager` and `authManager` are in scope at that call site (SettingsView already references `authManager.user?.role` at line 216; confirm `familyManager` is available — if not, read it from the environment the same way, or inject). If `FamilyMember` has no `familyUnitId` property, use the correct field name (grep `FamilyMember.swift`).

- [ ] **Step 4: Run — expect pass** (view tests) + build clean:

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'` then the `-only-testing:TheRecruitingCompassTests/VideoLinksEditorViewTests` command from Step 2.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/VideoLinks/Views/ \
        TheRecruitingCompass/TheRecruitingCompass/Features/Settings/Views/SettingsView.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/VideoLinks/VideoLinksEditorViewTests.swift
git commit -m "feat(ios): video-links editor screen + Settings entry (player edits, parents view-only)"
```

---

### Task 5: Extend the action-item CTA router to video

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/ActionItemCTA.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/ActionItemCard.swift` (`CardSheet` enum ~lines 15-19, `.sheet` switch ~lines 60-67, `presentCTA()` ~lines 115-121)
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/ActionItemSheets.swift` (add `ActionItemVideoLinksSheet`)
- Modify: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/ActionItemCTATests.swift` (the existing `test_videoAndUnknownAndNil_mapToNoneWithNilLabel` MUST change)

**Interfaces:**
- Consumes: `VideoLinksEditorView` (Task 4), the existing `ActionItemCard` sheet plumbing (`familyUnitId`, `userId`, `onActionCompleted`).
- Produces: `ActionItemCTA` gains `.addVideo` and `.updateVideo` cases (mapped from `"add_video"`/`"update_video"`, labels "Add Video"/"Update Video"); the card presents the video editor in a sheet for both.

> **Reconciliation:** this EXTENDS the Path A router — it does not build a new one. The `ActionItemCTA.swift` header comment already marks video as the intended gap. Do not create a parallel routing type.

- [ ] **Step 1: Update the failing test**

Replace `test_videoAndUnknownAndNil_mapToNoneWithNilLabel` in `ActionItemCTATests.swift` with:
```swift
func test_addVideoMapsToAddVideoWithLabel() {
  let cta = ActionItemCTA(actionType: "add_video")
  XCTAssertEqual(cta, .addVideo)
  XCTAssertEqual(cta.label, String(localized: "Add Video"))
}

func test_updateVideoMapsToUpdateVideoWithLabel() {
  let cta = ActionItemCTA(actionType: "update_video")
  XCTAssertEqual(cta, .updateVideo)
  XCTAssertEqual(cta.label, String(localized: "Update Video"))
}

func test_unknownAndNilMapToNoneWithNilLabel() {
  XCTAssertEqual(ActionItemCTA(actionType: "wat"), .none)
  XCTAssertEqual(ActionItemCTA(actionType: nil), .none)
  XCTAssertNil(ActionItemCTA(actionType: nil).label)
}
```

- [ ] **Step 2: Run — expect fail** (`.addVideo` case undefined).

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/ActionItemCTATests`

- [ ] **Step 3: Implement**

`ActionItemCTA.swift` — add the cases:
```swift
enum ActionItemCTA: Equatable {
  case addSchool
  case logInteraction
  case addVideo
  case updateVideo
  case none

  init(actionType: String?) {
    switch actionType {
    case "add_school": self = .addSchool
    case "log_interaction": self = .logInteraction
    case "add_video": self = .addVideo
    case "update_video": self = .updateVideo
    default: self = .none
    }
  }

  var label: String? {
    switch self {
    case .addSchool: return String(localized: "Add School")
    case .logInteraction: return String(localized: "Log Interaction")
    case .addVideo: return String(localized: "Add Video")
    case .updateVideo: return String(localized: "Update Video")
    case .none: return nil
    }
  }
}
```
Update the file's header comment (drop the "no iOS CTA today / Path B" note for video — it's now wired).

`ActionItemCard.swift`:
```swift
// CardSheet enum: add
case videoLinks
// presentCTA(): add
case .addVideo, .updateVideo: activeSheet = .videoLinks
// .sheet switch: add
case .videoLinks:
  ActionItemVideoLinksSheet(userId: userId)
```
(The card's `userId` is the acting user's id. The video editor scopes by athlete: for a player acting on their own suggestion, `userId` IS the athlete. Pass `userId` as `athleteUserId`; `familyUnitId` is already a card property — pass it too.)

`ActionItemSheets.swift` — mirror `ActionItemAddInteractionSheet`:
```swift
struct ActionItemVideoLinksSheet: View {
  let userId: String
  var familyUnitId: String? = nil
  var body: some View {
    NavigationStack {
      VideoLinksEditorView(athleteUserId: userId, familyUnitId: familyUnitId, isReadOnly: false)
    }
  }
}
```
> If the card already carries `familyUnitId`, thread it through (`ActionItemVideoLinksSheet(userId: userId, familyUnitId: familyUnitId)`), matching how `ActionItemAddInteractionSheet` receives it.

- [ ] **Step 4: Run — expect pass** (CTA tests) + build clean:

Run the `-only-testing:TheRecruitingCompassTests/ActionItemCTATests` command from Step 2, then `xcodebuild build ...` to confirm the card + sheet compile.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/ActionItemCTA.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/ActionItemCard.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/ActionItemSheets.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/ActionItemCTATests.swift
git commit -m "feat(ios): action-item video CTAs open the video-links editor (close Path B gap)"
```

---

### Task 6: Coach-comms film-links template variable

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateVariable.swift` (the `static let all` array)
- Investigate then (conditionally) modify: the template fill-value assembly site (NOT located during planning — Step 1 finds it via grep)
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateVariableTests.swift` (create or extend)

**Interfaces:**
- Consumes: existing `TemplateVariable`, `CommunicationTemplate.substituteVariables(in:values:)` (regex `\{\{(\w+)\}\}`).
- Produces: two insertable variables — `film_links` (all links, `Title (PLATFORM): url` newline-joined) and `primary_film_link` (first link's url) — available in the template editor's insert-chip grid; filled with real values IF the fill site is reachable with athlete video links, else picker-only with a documented follow-up.

> **Scope guard (master design §6.4):** the variable-insertion system exists (definitions in `TemplateVariable.all`, chip UI in `TemplateEditorView.swift`, substitution in `CommunicationTemplate.swift`). Adding the *definitions* is in scope. Wiring the *fill values* is in scope ONLY if the fill-dictionary assembly site can reach the athlete's video links without new plumbing; if the fill happens somewhere that has no video-links access, add the definitions (so the chips work + web parity of the token names) and record the fill wiring as a follow-up in `CLAUDE.local.md` — do NOT expand scope to thread a service through an unrelated compose flow.

- [ ] **Step 1: Locate the fill site**

Run: `cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios && grep -rn "substituteVariables\|bodyFilled\|TemplateVariable" TheRecruitingCompass/TheRecruitingCompass/Features --include=*.swift`
Record every call site that builds the `values` dictionary passed to `substituteVariables`/`bodyFilled`. Decide reachability: does that view/VM already hold (or can trivially load) the athlete's video links? Note the finding in the commit message.

- [ ] **Step 2: Write the failing test**

```swift
// TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateVariableTests.swift
import XCTest
@testable import TheRecruitingCompass

final class TemplateVariableTests: XCTestCase {
  func test_filmLinkVariablesAreOffered() {
    let keys = TemplateVariable.all.map(\.key)
    XCTAssertTrue(keys.contains("film_links"))
    XCTAssertTrue(keys.contains("primary_film_link"))
  }

  func test_substitutionReplacesFilmLinks() {
    let template = CommunicationTemplate.preview  // or construct a minimal instance
    let filled = template.substituteVariables(
      in: "Watch: {{primary_film_link}}",
      values: ["primary_film_link": "https://hudl.com/x"])
    XCTAssertEqual(filled, "Watch: https://hudl.com/x")
  }
}
```
> Adjust the second test to the real signature of the substitution method found in `CommunicationTemplate.swift:82-114` (it may be a static/instance func named `substituteVariables(in:values:)` or `bodyFilled(with:)`). If it is instance-bound and no cheap preview instance exists, test the static path or the smallest constructible instance. Do not weaken the assertion — it must prove `{{primary_film_link}}` is replaced.

- [ ] **Step 3: Run — expect fail** (keys absent).

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/TemplateVariableTests`

- [ ] **Step 4: Implement**

In `TemplateVariable.swift`, append to `static let all`:
```swift
TemplateVariable(name: "Film Links", key: "film_links"),
TemplateVariable(name: "Primary Film Link", key: "primary_film_link")
```
Then, IF Step 1 found a reachable fill site: at that site, load the athlete's links (`VideoLinksServiceImpl().fetchVideoLinks(userId: athleteUserId)`) and add to the `values` dict:
- `primary_film_link` = first link's `url` (prefer `.healthy`; fallback first; else `""`)
- `film_links` = links mapped to `"\(title ?? url) (\(platform.displayName.uppercased())): \(url)"` joined by `"\n"`; `""` if none.
IF NOT reachable: stop after the definitions and write a `CLAUDE.local.md` follow-up note ("Phase C: `film_links`/`primary_film_link` variables are insertable but not yet filled — wire values at <fill site> when a video-links-aware compose flow exists"). Either way, Steps 2's tests pass (they assert offering + the pure substitution mechanism).

- [ ] **Step 5: Run — expect pass** (same command as Step 3) + build clean.

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates/Models/TemplateVariable.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/CommunicationTemplates/TemplateVariableTests.swift
# plus the fill-site file if wired
git commit -m "feat(ios): film-links coach-comms template variables (definitions + fill if reachable)"
```

---

## Self-Review

- **Spec coverage (master design §6):** §6.1 model+service → Tasks 1-2; §6.2 editor in player-details settings (player-only, max-5, health badge) → Tasks 3-4; §6.3 CTA router (reconciled with Path A, not from scratch) → Task 5; §6.4 comms var parity (verified system exists; fill-value conditionally scoped) → Task 6. All four §6 items covered. ✓
- **Testing (design §9-C):** service CRUD via mock (T2), editor VM tests max-5/player-only (T3), CTA-router mapping each action_type→destination incl. unknown→none (T5). ✓
- **Placeholder scan:** every code step carries real Swift + exact file:line anchors from the research pass; the two genuinely-unknown spots (Task 4 `familyManager` scope at the SettingsView call site; Task 6 fill site) are explicit investigate-then-act steps with a decision rule, not hand-waves. ✓
- **Type consistency:** `VideoLink`, `VideoLinkPlatform`, `VideoLinkHealth`, `VideoLinksManaging`, `VideoLinkCreateRequest`/`VideoLinkUpdateRequest`, `VideoLinksEditorViewModel`, `VideoLinksEditorView`, `ActionItemVideoLinksSheet`, CTA cases `.addVideo`/`.updateVideo` — names used identically T1→T6. ✓
- **Non-goals honored (design §7):** no top-level Videos tab (editor is a SettingsDestination); highlight_video *documents* untouched; no platform API (health is read-only badge from the cron's `health_status`). ✓

## Open Risks (flagged for the executor / reviewer)

1. **`FamilyMember.familyUnitId` field name** — Task 4/5 assume it exists; grep `FamilyMember.swift` (research found `userId`→`user_id` at line 5/21 but did not confirm a `familyUnitId` field). If absent, resolve family id the way `ActionItemCard`'s existing `familyUnitId` input is sourced (it already flows one in — reuse that path).
2. **`familyManager` availability in `SettingsView`** — confirmed `authManager` is in scope there; `familyManager` needs a scope check (env object vs injected). Task 4 Step 3 calls this out.
3. **Task 6 fill site** — genuinely unlocated; the task is written to succeed either way (definitions always land; fill wired only if reachable). This is the one place scope may legitimately shrink to a follow-up per design §6.4.
4. **RLS write needs `family_unit_id`** — Phase A grants owning-player write with a family tie-back; `VideoLinkCreateRequest` carries `familyUnitId`. If inserts 403 in E2E, verify the create payload's `family_unit_id` matches the player's family (source it from the same place the create's `user_id` comes from).

## Execution Handoff

Depends on Phase A's `video_links` table (shipped, unmerged on web `feat/video-links`) and Phase B's API/contract (parallel; iOS talks to the table directly via Supabase, not the web API, so B is not a hard blocker for C). Recommended order: T1 → T2 → T3 → T4 (editor stack), then T5 (needs T4's view for the sheet); T6 is independent and can run any time after T1.
