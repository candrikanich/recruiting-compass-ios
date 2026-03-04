# Add School Web Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Route College Scorecard API calls through the web app proxy (removing the embedded API key) and add post-creation favicon fire-and-forget to match the web app's behavior exactly.

**Architecture:** Two independent changes: (1) `CollegeScorecardService` rewritten to call `{apiBaseURL}/api/colleges/search` with Bearer token auth — same response JSON, same decode models, no protocol change; (2) new `SchoolFaviconService` that fires after school creation to call `{apiBaseURL}/api/schools/favicon`, receives the best-quality logo URL, and writes it back to Supabase. Both services get their auth token via `SupabaseManager.shared.client.auth.session`.

**Tech Stack:** Swift 6, `async`/`actor`, Supabase iOS SDK, `URLSession`

**Reference:** `planning/iOS_EXPLAINER_AddSchool_API_Calls.md` (web app companion doc)

---

## Task 1: Rewrite `CollegeScorecardService` to use web app proxy

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Services/CollegeScorecardService.swift`

**Context:**
The current service calls `api.data.gov` directly using `SupabaseConfigEmbedded.collegeScorecardApiKey`. The proxy endpoint is `GET {apiBaseURL}/api/colleges/search` with `Authorization: Bearer {accessToken}`. The response format is identical (dot-notation JSON keys like `school.name`, `location.lat`) so the existing `CollegeDataResult`, `CollegeScorecardAPIResponse`, and `AutocompleteAPIResponse` decode models need no changes.

The `CollegeScorecardManaging` protocol is **unchanged** — callers don't need to be updated.

**Query parameters for each method:**

- `searchColleges(query:)` → `?q={query}&fields=id,school.name,school.city,school.state,school.school_url&per_page=10`
- `lookupCollege(id:)` → `?id={id}&fields=id,school.name,school.school_url,school.address,school.city,school.state,latest.student.size,school.carnegie_size_setting,enrollment.all,latest.admissions.admission_rate.overall,latest.student.student_faculty_ratio,latest.cost.tuition.in_state,latest.cost.tuition.out_of_state,location.lat,location.lon`
- `lookupCollege(name:)` → same fields as id-lookup but `?q={name}` instead of `?id=`

**Error mapping:**
- `apiBaseURL` is nil → throw `CollegeDataError.apiKeyMissing`
- Token is nil/empty → throw `CollegeDataError.apiKeyMissing`
- HTTP 401/403 → `CollegeDataError.invalidApiKey`
- HTTP 429 → `CollegeDataError.rateLimited`
- HTTP 5xx → `CollegeDataError.serverError(statusCode)`
- Other non-200 → `CollegeDataError.invalidResponse`

**Step 1: Write the complete replacement**

Replace the entire contents of `CollegeScorecardService.swift` with:

```swift
import Foundation
import OSLog
import Supabase

nonisolated private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "CollegeScorecardService"
)

protocol CollegeScorecardManaging: Sendable {
  func lookupCollege(name: String) async throws -> CollegeDataResult?
  func lookupCollege(id: String) async throws -> CollegeDataResult?
  func searchColleges(query: String) async throws -> [CollegeSearchResult]
}

/// Routes College Scorecard requests through the web app proxy at /api/colleges/search.
/// Auth: Supabase session Bearer token. Falls back to CollegeDataError.apiKeyMissing when
/// API_BASE_URL or session token is unavailable.
actor CollegeScorecardService: CollegeScorecardManaging {
  private let urlSession: URLSession
  private let cache = CollegeScorecardCache()

  init(urlSession: URLSession = .shared) {
    self.urlSession = urlSession
  }

  // MARK: - Public API

  func searchColleges(query: String) async throws -> [CollegeSearchResult] {
    guard query.count >= 3 else { throw CollegeDataError.nameTooShort }

    if let cached = await cache.getSearch(for: query) {
      logger.debug("Cache hit for search: \(query)")
      return cached
    }

    logger.debug("Searching colleges via proxy: \(query)")

    let fields = [
      "id", "school.name", "school.city", "school.state", "school.school_url"
    ].joined(separator: ",")

    let url = try buildURL(queryItems: [
      URLQueryItem(name: "q", value: query),
      URLQueryItem(name: "fields", value: fields),
      URLQueryItem(name: "per_page", value: "10")
    ])

    let data = try await fetchData(from: url)
    let response = try JSONDecoder().decode(AutocompleteAPIResponse.self, from: data)
    let results = transformAutocompleteResults(response.results)

    logger.info("Found \(results.count) colleges for query: \(query)")
    await cache.setSearch(for: query, results: results)
    return results
  }

  func lookupCollege(name: String) async throws -> CollegeDataResult? {
    guard name.count >= 3 else { throw CollegeDataError.nameTooShort }

    let cacheKey = name.lowercased()
    if let cached = await cache.getLookup(for: cacheKey) {
      logger.debug("Cache hit for lookup: \(name)")
      return cached
    }

    logger.debug("Looking up college via proxy: \(name)")

    let url = try buildURL(queryItems: [
      URLQueryItem(name: "q", value: name),
      URLQueryItem(name: "fields", value: detailFields),
      URLQueryItem(name: "per_page", value: "1")
    ])

    let data = try await fetchData(from: url)
    let response = try JSONDecoder().decode(CollegeScorecardAPIResponse.self, from: data)
    let result = response.results.first

    logger.info(result != nil ? "Found college: \(result!.name)" : "No results for: \(name)")
    await cache.setLookup(for: cacheKey, result: result)
    return result
  }

  func lookupCollege(id: String) async throws -> CollegeDataResult? {
    let cacheKey = "id:\(id)"
    if let cached = await cache.getLookup(for: cacheKey) {
      logger.debug("Cache hit for lookup id: \(id)")
      return cached
    }

    logger.debug("Looking up college by id via proxy: \(id)")

    let url = try buildURL(queryItems: [
      URLQueryItem(name: "id", value: id),
      URLQueryItem(name: "fields", value: detailFields)
    ])

    let data = try await fetchData(from: url)
    let response = try JSONDecoder().decode(CollegeScorecardAPIResponse.self, from: data)
    let result = response.results.first

    logger.info(result != nil ? "Found college: \(result!.name)" : "No results for id: \(id)")
    await cache.setLookup(for: cacheKey, result: result)
    return result
  }

  // MARK: - Private Helpers

  private let detailFields = [
    "id", "school.name", "school.school_url", "school.address",
    "school.city", "school.state", "latest.student.size",
    "school.carnegie_size_setting", "enrollment.all",
    "latest.admissions.admission_rate.overall",
    "latest.student.student_faculty_ratio",
    "latest.cost.tuition.in_state", "latest.cost.tuition.out_of_state",
    "location.lat", "location.lon"
  ].joined(separator: ",")

  private func buildURL(queryItems: [URLQueryItem]) throws -> URL {
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      throw CollegeDataError.apiKeyMissing
    }
    var components = URLComponents(
      url: baseURL.appendingPathComponent("api/colleges/search"),
      resolvingAgainstBaseURL: false
    )!
    components.queryItems = queryItems
    guard let url = components.url else { throw CollegeDataError.invalidResponse }
    return url
  }

  private func fetchData(from url: URL) async throws -> Data {
    guard let token = try? await SupabaseManager.shared.client.auth.session.accessToken,
          !token.isEmpty else {
      throw CollegeDataError.apiKeyMissing
    }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    do {
      let (data, response) = try await urlSession.data(for: request)
      guard let http = response as? HTTPURLResponse else {
        throw CollegeDataError.invalidResponse
      }
      logger.debug("Proxy response status: \(http.statusCode)")
      try validateStatus(http.statusCode)
      return data
    } catch let error as CollegeDataError {
      throw error
    } catch {
      logger.error("Network error: \(error.localizedDescription)")
      throw CollegeDataError.networkError(error)
    }
  }

  private func validateStatus(_ code: Int) throws {
    switch code {
    case 200: return
    case 401, 403: throw CollegeDataError.invalidApiKey
    case 429: throw CollegeDataError.rateLimited
    case 500...599: throw CollegeDataError.serverError(code)
    default: throw CollegeDataError.invalidResponse
    }
  }

  private func transformAutocompleteResults(
    _ results: [AutocompleteAPIResponse.AutocompleteResult]
  ) -> [CollegeSearchResult] {
    results.compactMap { r -> CollegeSearchResult? in
      guard let id = r.id, let name = r.name,
            let city = r.city, let state = r.state else { return nil }
      return CollegeSearchResult(
        id: String(id), name: name, city: city, state: state, website: r.website
      )
    }
  }
}

// MARK: - Cache

private actor CollegeScorecardCache {
  private struct Entry<T> { let value: T; let expiry: Date }
  private var lookupCache: [String: Entry<CollegeDataResult?>] = [:]
  private var searchCache: [String: Entry<[CollegeSearchResult]>] = [:]
  private let ttl: TimeInterval = 600

  func getLookup(for key: String) -> CollegeDataResult?? {
    guard let e = lookupCache[key], e.expiry > Date() else {
      lookupCache.removeValue(forKey: key); return nil
    }
    return e.value
  }

  func setLookup(for key: String, result: CollegeDataResult?) {
    lookupCache[key] = Entry(value: result, expiry: Date().addingTimeInterval(ttl))
  }

  func getSearch(for query: String) -> [CollegeSearchResult]? {
    let key = query.lowercased()
    guard let e = searchCache[key], e.expiry > Date() else {
      searchCache.removeValue(forKey: key); return nil
    }
    return e.value
  }

  func setSearch(for query: String, results: [CollegeSearchResult]) {
    searchCache[query.lowercased()] = Entry(value: results, expiry: Date().addingTimeInterval(ttl))
  }
}
```

**Step 2: Verify build**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
make build
```

Expected: BUILD SUCCEEDED with no errors.

**Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Services/CollegeScorecardService.swift
git commit -m "feat(schools): route College Scorecard calls through web app proxy

Remove embedded API key. All three methods (searchColleges, lookupCollege by
id/name) now call {apiBaseURL}/api/colleges/search with Supabase Bearer token.
Response format is identical so decode models are unchanged. Protocol unchanged."
```

---

## Task 2: Remove `COLLEGE_SCORECARD_API_KEY` from config

**Files:**
- Modify: `TheRecruitingCompass/Release.xcconfig`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseConfig.generated.swift`

**Context:**
The xcconfig bakes `COLLEGE_SCORECARD_API_KEY` into the binary via the Xcode build phase script that generates `SupabaseConfig.generated.swift`. Since we no longer use it, remove the key from xcconfig so it's not embedded in future builds. Also update the currently-committed generated file to clear the value (the build phase will regenerate it correctly on next build).

**Step 1: Clear the key in `Release.xcconfig`**

Remove or blank out the line:
```
COLLEGE_SCORECARD_API_KEY = foAWuv61Me44aq03lw5TNmGxpVeFdxChbQeHaEWi
```
Replace with:
```
COLLEGE_SCORECARD_API_KEY =
```

**Step 2: Update the generated file**

In `SupabaseConfig.generated.swift`, change:
```swift
static let collegeScorecardApiKey = "foAWuv61Me44aq03lw5TNmGxpVeFdxChbQeHaEWi"
```
to:
```swift
static let collegeScorecardApiKey = ""
```

**Step 3: Verify build**

```bash
make build
```

Expected: BUILD SUCCEEDED. The `collegeScorecardApiKey` property still exists (build script still generates it) but holds an empty string and is no longer referenced.

**Step 4: Commit**

```bash
git add TheRecruitingCompass/Release.xcconfig \
        TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseConfig.generated.swift
git commit -m "chore(config): remove College Scorecard API key from build config

Key is no longer used; all Scorecard calls now go through web app proxy."
```

---

## Task 3: Create `SchoolFaviconService`

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Services/SchoolFaviconService.swift`

**Context:**
After a school is created, this service is called fire-and-forget. It:
1. Calls `GET {apiBaseURL}/api/schools/favicon?schoolDomain={domain}&schoolId={id}` with Bearer token
2. On success: writes the returned `faviconUrl` to the `schools` table in Supabase
3. Silent failure throughout — the school works fine without a favicon

Domain extraction rules (must match the web):
- Strip `https://`, `http://`, `www.`
- Strip path and query string (everything after first `/` or `?`)
- Fallback if no website: `{lowercased-no-spaces-name}.edu`

**Response shape from proxy:**
```json
{
  "success": true,
  "faviconUrl": "https://www.google.com/s2/favicons?sz=256&domain=ufl.edu",
  "domain": "ufl.edu",
  "schoolId": "uuid-string"
}
```
`faviconUrl` may be `null` — skip the Supabase write in that case.

**Step 1: Write the service**

Create `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Services/SchoolFaviconService.swift`:

```swift
import Foundation
import OSLog
import Supabase

nonisolated private let faviconLogger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "SchoolFaviconService"
)

protocol SchoolFaviconManaging: Sendable {
  func fetchAndPersist(school: School) async
}

/// Fetches the best-quality favicon/logo for a school via the web app proxy
/// and writes it back to Supabase. All failures are silent — the school
/// functions normally without a favicon.
actor SchoolFaviconService: SchoolFaviconManaging {
  private let urlSession: URLSession

  init(urlSession: URLSession = .shared) {
    self.urlSession = urlSession
  }

  func fetchAndPersist(school: School) async {
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      faviconLogger.debug("Favicon skipped: API_BASE_URL not configured")
      return
    }

    let domain = extractDomain(from: school.website) ?? fallbackDomain(for: school.name)
    guard !domain.isEmpty else {
      faviconLogger.debug("Favicon skipped: could not derive domain for \(school.name)")
      return
    }

    guard let token = try? await SupabaseManager.shared.client.auth.session.accessToken,
          !token.isEmpty else {
      faviconLogger.debug("Favicon skipped: no auth token")
      return
    }

    guard var components = URLComponents(
      url: baseURL.appendingPathComponent("api/schools/favicon"),
      resolvingAgainstBaseURL: false
    ) else { return }
    components.queryItems = [
      URLQueryItem(name: "schoolDomain", value: domain),
      URLQueryItem(name: "schoolId", value: school.id)
    ]
    guard let url = components.url else { return }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    do {
      let (data, response) = try await urlSession.data(for: request)
      guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        faviconLogger.warning("Favicon fetch failed for \(school.name)")
        return
      }

      let decoded = try JSONDecoder().decode(FaviconResponse.self, from: data)
      guard let faviconUrl = decoded.faviconUrl, !faviconUrl.isEmpty else {
        faviconLogger.debug("No favicon found for \(school.name)")
        return
      }

      try await SupabaseManager.shared.client
        .from("schools")
        .update(["favicon_url": faviconUrl])
        .eq("id", value: school.id)
        .execute()

      faviconLogger.info("Favicon persisted for \(school.name): \(faviconUrl)")

    } catch {
      faviconLogger.warning("Favicon error for \(school.name): \(error.localizedDescription)")
    }
  }

  // MARK: - Domain Helpers

  private func extractDomain(from website: String?) -> String? {
    guard let raw = website, !raw.isEmpty else { return nil }
    var domain = raw.lowercased()
      .replacingOccurrences(of: "https://", with: "")
      .replacingOccurrences(of: "http://", with: "")
      .replacingOccurrences(of: "www.", with: "")
    if let cut = domain.firstIndex(of: "/") { domain = String(domain[..<cut]) }
    if let cut = domain.firstIndex(of: "?") { domain = String(domain[..<cut]) }
    domain = domain.trimmingCharacters(in: .whitespaces)
    guard domain.contains("."), !domain.hasPrefix(".") else { return nil }
    return domain.isEmpty ? nil : domain
  }

  private func fallbackDomain(for name: String) -> String {
    let slug = name.lowercased()
      .components(separatedBy: .whitespaces)
      .joined()
      .components(separatedBy: .punctuationCharacters)
      .joined()
    return "\(slug).edu"
  }
}

// MARK: - Response Model

private struct FaviconResponse: Decodable {
  let success: Bool
  let faviconUrl: String?
  let domain: String?
  let schoolId: String?
}
```

**Step 2: Build**

```bash
make build
```

Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Services/SchoolFaviconService.swift
git commit -m "feat(schools): add SchoolFaviconService for post-create logo fetch

Fire-and-forget service calls /api/schools/favicon after school creation,
tries multiple favicon sources server-side, and writes the best URL back
to Supabase. All failures are silent."
```

---

## Task 4: Remove favicon derivation from `SchoolCreateRequest`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/SchoolCreateRequest+Preparation.swift`

**Context:**
`SchoolCreateRequest.from(form:scorecardData:userId:familyUnitId:)` currently calls `Self.faviconUrlFromWebsite(...)` and passes the result to `faviconUrl:`. Now that Phase 5 handles favicon post-creation, the school should be created with `faviconUrl: nil`.

Remove these two private static methods:
- `faviconUrlFromWebsite(_:) -> String?`
- `extractDomain(from:) -> String?`

And change the `faviconUrl:` argument in the `SchoolCreateRequest(...)` init call from `Self.faviconUrlFromWebsite(...)` to `nil`.

**Step 1: Edit the file**

In `SchoolCreateRequest+Preparation.swift`:

1. In the `SchoolCreateRequest(...)` init call, change:
   ```swift
   faviconUrl: faviconUrl
   ```
   to:
   ```swift
   faviconUrl: nil
   ```
   (and remove the `let faviconUrl = Self.faviconUrlFromWebsite(...)` line above it)

2. Delete the entire `faviconUrlFromWebsite(_:)` private method.

3. Delete the entire `extractDomain(from:)` private method.

**Step 2: Build**

```bash
make build
```

Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools/Models/SchoolCreateRequest+Preparation.swift
git commit -m "refactor(schools): create school without favicon_url

Favicon is now fetched post-creation by SchoolFaviconService (Phase 5).
Remove faviconUrlFromWebsite helper that baked a static Google URL into
the create request."
```

---

## Task 5: Wire `SchoolFaviconService` into `AddSchoolViewModel`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/AddSchoolViewModel.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/AddSchoolViewModel+DuplicateDetection.swift`

**Context:**
`AddSchoolViewModel` needs a `schoolFaviconService: SchoolFaviconManaging` dependency. The convenience init provides the default. After `createSchoolInternal` succeeds, launch a detached `Task` (fire-and-forget) that calls `schoolFaviconService.fetchAndPersist(school:)`.

**Step 1: Add dependency to `AddSchoolViewModel.swift`**

In the `// MARK: - Dependencies` section, add:
```swift
internal let schoolFaviconService: SchoolFaviconManaging
```

In the designated `nonisolated init(...)`, add the parameter:
```swift
schoolFaviconService: SchoolFaviconManaging,
```
and assign it:
```swift
self.schoolFaviconService = schoolFaviconService
```

In the `convenience init(schoolsService:familyUnitId:userId:)`, pass the default:
```swift
self.init(
  schoolsService: schoolsService,
  collegeScorecardService: CollegeScorecardService(),
  ncaaDatabase: NcaaDatabase.shared,
  schoolFaviconService: SchoolFaviconService(),
  familyUnitId: familyUnitId,
  userId: userId,
  announcer: UIAccessibilityAnnouncer()
)
```

**Step 2: Fire-and-forget in `AddSchoolViewModel+DuplicateDetection.swift`**

In `createSchoolInternal`, after:
```swift
let newSchool = try await schoolsService.createSchool(request: request)
duplicateLogger.info("School created successfully: \(newSchool.id)")
```

Add:
```swift
// Phase 5: Fetch and persist favicon — fire-and-forget, do not await
let faviconService = schoolFaviconService
Task.detached {
  await faviconService.fetchAndPersist(school: newSchool)
}
```

**Step 3: Build**

```bash
make build
```

Expected: BUILD SUCCEEDED.

**Step 4: Run tests**

```bash
make test-unit
```

Expected: All tests pass. (The favicon service is not called by existing tests since they use mock dependencies.)

**Step 5: Commit**

```bash
git add \
  TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/AddSchoolViewModel.swift \
  TheRecruitingCompass/TheRecruitingCompass/Features/Schools/ViewModels/AddSchoolViewModel+DuplicateDetection.swift
git commit -m "feat(schools): wire favicon fire-and-forget into AddSchoolViewModel

After school creation succeeds, detach a Task to fetch and persist the
school logo via SchoolFaviconService. Navigation proceeds immediately;
favicon appears on next load once the background task writes back to DB."
```

---

## Verification Checklist

After all tasks are complete, manually verify:

- [ ] Add a school via autocomplete — college search results appear (proxy is working)
- [ ] Division/conference auto-fill still works (NCAA lookup is local, unchanged)
- [ ] College Scorecard enrichment data (tuition, enrollment, etc.) still appears
- [ ] School creates successfully
- [ ] In Xcode console, see log line: `Favicon persisted for {SchoolName}: https://...` (or `Favicon skipped: API_BASE_URL not configured` if running without API_BASE_URL)
- [ ] After a few seconds, check the school record in Supabase — `favicon_url` column is populated
- [ ] Build in release config — no embedded Scorecard API key in binary
