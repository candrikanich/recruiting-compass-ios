# Security Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all 8 security/correctness issues found in the 2026-03-03 security review.

**Architecture:** Surgical edits across FamilyServiceImpl, DashboardServiceImpl, DeepLinkHandler, SupabaseManager, Release.xcconfig, and the Xcode build phase script. No new files needed.

**Tech Stack:** Swift, SwiftUI, Xcode build phases (shell script in pbxproj), OSLog

---

### Task 1: Remove dead College Scorecard API key from binary

The key lives in three places: Release.xcconfig, the build phase shellScript in project.pbxproj, and SupabaseConfig.generated.swift (generated at build time). Remove from all three.

**Files:**
- Modify: `TheRecruitingCompass/Release.xcconfig:11`
- Modify: `TheRecruitingCompass/TheRecruitingCompass.xcodeproj/project.pbxproj` (build phase shellScript)
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseConfig.generated.swift`

**Step 1: Remove from Release.xcconfig**

Delete line 11 (`COLLEGE_SCORECARD_API_KEY = foAWuv61Me44aq03lw5TNmGxpVeFdxChbQeHaEWi`).

**Step 2: Remove from build phase script in pbxproj using Python**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
python3 - <<'PYEOF'
import re

with open("TheRecruitingCompass.xcodeproj/project.pbxproj", "r") as f:
    content = f.read()

# Remove CSC_ESC variable assignment line from the shell script
content = content.replace(
    r"""\nCSC_ESC=$(printf '%s' \"${COLLEGE_SCORECARD_API_KEY:-}\" | sed 's/\\\\/\\\\\\\\/g; s/\"/\\\\\"/g')""",
    ""
)

# Remove collegeScorecardApiKey line from the printf format string
content = content.replace(
    r"""\\n  static let collegeScorecardApiKey = \"%s\"""",
    ""
)

# Remove $CSC_ESC argument from the printf call
content = content.replace(
    """ \"$CSC_ESC\"""",
    ""
)

with open("TheRecruitingCompass.xcodeproj/project.pbxproj", "w") as f:
    f.write(content)
print("Done")
PYEOF
```

**Step 3: Update the already-generated SupabaseConfig.generated.swift on disk**

Remove line 8 (`static let collegeScorecardApiKey = "foAWuv61Me44aq03lw5TNmGxpVeFdxChbQeHaEWi"`).

**Step 4: Build to verify**

```bash
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 5: Commit**

```bash
git add TheRecruitingCompass/Release.xcconfig TheRecruitingCompass/TheRecruitingCompass.xcodeproj/project.pbxproj "TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseConfig.generated.swift"
git commit -m "security: remove College Scorecard API key from build artifacts"
```

---

### Task 2: Fix declineInvite missing Authorization header

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Services/FamilyServiceImpl.swift:444-460`

**Step 1: Add auth header to declineInvite**

Current code at line 444:
```swift
func declineInvite(token: String) async throws {
  guard let baseURL = SupabaseConfig.apiBaseURL else {
    throw FamilyError.serverError("API base URL not configured")
  }

  var request = URLRequest(
    url: baseURL.appendingPathComponent("api/family/invite/\(token)/decline")
  )
  request.httpMethod = "POST"
  request.setValue("application/json", forHTTPHeaderField: "Content-Type")
  request.httpBody = Data("{}".utf8)
```

Replace with:
```swift
func declineInvite(token: String) async throws {
  guard let baseURL = SupabaseConfig.apiBaseURL else {
    throw FamilyError.serverError("API base URL not configured")
  }
  let accessToken = try await supabaseManager.client.auth.session.accessToken

  let safeToken = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
  var request = URLRequest(
    url: baseURL
      .appendingPathComponent("api/family/invite")
      .appendingPathComponent(safeToken)
      .appendingPathComponent("decline")
  )
  request.httpMethod = "POST"
  request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
  request.setValue("application/json", forHTTPHeaderField: "Content-Type")
  request.httpBody = Data("{}".utf8)
```

Note: This fix also applies path sanitization (Issue 2) for this endpoint simultaneously.

**Step 2: Commit**

```bash
git add "TheRecruitingCompass/TheRecruitingCompass/Features/Family/Services/FamilyServiceImpl.swift"
git commit -m "fix(security): add Authorization header to declineInvite, sanitize token path"
```

---

### Task 3: Sanitize URL path segments in FamilyServiceImpl

Fix remaining URL construction in `revokeInvitation`, `lookupInviteByToken`, and `acceptInvite` to use separate `appendingPathComponent` calls per segment.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Services/FamilyServiceImpl.swift`

**revokeInvitation (line ~387):**
```swift
// Before:
url: baseURL.appendingPathComponent("api/family/invitations/\(id)")

// After:
url: baseURL
  .appendingPathComponent("api/family/invitations")
  .appendingPathComponent(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)
```

**lookupInviteByToken (line ~404):**
```swift
// Before:
let url = baseURL.appendingPathComponent("api/family/invite/\(token)")

// After:
let safeToken = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
let url = baseURL
  .appendingPathComponent("api/family/invite")
  .appendingPathComponent(safeToken)
```

**acceptInvite (line ~431):**
```swift
// Before:
url: baseURL.appendingPathComponent("api/family/invite/\(token)/accept")

// After (token already declared as accessToken earlier, use different name):
let safeToken = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
// ...
url: baseURL
  .appendingPathComponent("api/family/invite")
  .appendingPathComponent(safeToken)
  .appendingPathComponent("accept")
```

**Step 2: Commit**

```bash
git add "TheRecruitingCompass/TheRecruitingCompass/Features/Family/Services/FamilyServiceImpl.swift"
git commit -m "fix(security): sanitize URL path segments in FamilyServiceImpl"
```

---

### Task 4: Sanitize URL path segments in DashboardServiceImpl

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Services/DashboardServiceImpl.swift`

**dismissSuggestion (line ~222):**
```swift
// Before:
let url = baseURL.appendingPathComponent("api/suggestions/\(id)/dismiss")

// After:
let safeId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
let url = baseURL
  .appendingPathComponent("api/suggestions")
  .appendingPathComponent(safeId)
  .appendingPathComponent("dismiss")
```

**completeSuggestion (line ~252):**
```swift
// Before:
let url = baseURL.appendingPathComponent("api/suggestions/\(id)/complete")

// After:
let safeId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
let url = baseURL
  .appendingPathComponent("api/suggestions")
  .appendingPathComponent(safeId)
  .appendingPathComponent("complete")
```

**Step 2: Commit**

```bash
git add "TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Services/DashboardServiceImpl.swift"
git commit -m "fix(security): sanitize URL path segments in DashboardServiceImpl"
```

---

### Task 5: Validate deep link token format in DeepLinkHandler

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/DeepLinkHandler.swift`

**Step 1: Add token validation helper and apply to both invite paths**

```swift
// Add private helper before parse():
private static let inviteTokenAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))

private static func isValidInviteToken(_ token: String) -> Bool {
  !token.isEmpty && token.unicodeScalars.allSatisfy { inviteTokenAllowed.contains($0) }
}
```

Apply to the `/join?token=...` path:
```swift
// Before:
let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
!token.isEmpty {

// After:
let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
isValidInviteToken(token) {
```

Apply to the `/invite/:token` path:
```swift
// Before:
let token = url.path
  .replacingOccurrences(of: "/invite/", with: "")
  .trimmingCharacters(in: .whitespacesAndNewlines)
if !token.isEmpty {
  return .joinInvite(token: token)
}

// After:
let token = url.path
  .replacingOccurrences(of: "/invite/", with: "")
  .trimmingCharacters(in: .whitespacesAndNewlines)
if isValidInviteToken(token) {
  return .joinInvite(token: token)
}
```

Also wrap debug hosts in `#if DEBUG`:
```swift
// Before:
static let universalLinkHosts: Set<String> = [
  "myrecruitingcompass.com",
  "www.myrecruitingcompass.com",
  "localhost",
  "127.0.0.1",
]

// After:
static let universalLinkHosts: Set<String> = {
  var hosts: Set<String> = [
    "myrecruitingcompass.com",
    "www.myrecruitingcompass.com",
  ]
  #if DEBUG
  hosts.insert("localhost")
  hosts.insert("127.0.0.1")
  #endif
  return hosts
}()
```

**Step 2: Commit**

```bash
git add "TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/DeepLinkHandler.swift"
git commit -m "fix(security): validate invite token format in DeepLinkHandler, restrict debug hosts"
```

---

### Task 6: Fix family code generation length (6 → 8 chars)

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Services/FamilyServiceImpl.swift:186`

`FormValidator.familyCodePattern` expects `FAM-[A-Z0-9]{8}` (8 chars after prefix), but `createFamily` generates only 6.

```swift
// Before:
let familyCode = "FAM-" + String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })

// After:
let familyCode = "FAM-" + String((0..<8).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
```

**Step 2: Commit**

```bash
git add "TheRecruitingCompass/TheRecruitingCompass/Features/Family/Services/FamilyServiceImpl.swift"
git commit -m "fix(security): align family code generation length with validator (6→8 chars)"
```

---

### Task 7: Apply privacy: .private to user IDs in SupabaseManager logs

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift`

Three log lines missing `privacy: .private` on userId:

Line 323:
```swift
// Before:
logger.info("Successfully fetched user profile for \(userId)")
// After:
logger.info("Successfully fetched user profile for \(userId, privacy: .private)")
```

Line 334:
```swift
// Before:
logger.error("All retries failed for user \(userId), falling back to metadata")
// After:
logger.error("All retries failed for user \(userId, privacy: .private), falling back to metadata")
```

Line 352:
```swift
// Before:
logger.info("Upserted user \(userId) into users table from metadata fallback")
// After:
logger.info("Upserted user \(userId, privacy: .private) into users table from metadata fallback")
```

**Step 2: Commit**

```bash
git add "TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift"
git commit -m "fix(security): redact user IDs in SupabaseManager log statements"
```

---

### Task 8: Redact server response bodies in FamilyServiceImpl logs

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Services/FamilyServiceImpl.swift`

Line 346:
```swift
// Before:
logger.error("sendEmailInvite failed: status=\(http.statusCode), body=\(bodyString, privacy: .public)")
// After:
logger.error("sendEmailInvite failed: status=\(http.statusCode), body=\(bodyString, privacy: .private)")
```

Line 376:
```swift
// Before:
logger.error("fetchPendingInvitations decode failed: \(error.localizedDescription, privacy: .public), body=\(bodyPreview, privacy: .public)")
// After:
logger.error("fetchPendingInvitations decode failed: \(error.localizedDescription, privacy: .public), body=\(bodyPreview, privacy: .private)")
```

(Error description is fine as public; the body content is the sensitive part.)

**Step 2: Commit**

```bash
git add "TheRecruitingCompass/TheRecruitingCompass/Features/Family/Services/FamilyServiceImpl.swift"
git commit -m "fix(security): redact server response bodies in FamilyServiceImpl error logs"
```

---

### Task 9: Final build + test verification

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "PASS|FAIL|error:|BUILD"
```

Expected: All tests pass, build succeeds.
