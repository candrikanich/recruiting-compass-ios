# Phase 6b — Text() call-site localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every `Text(...)` call site in app source catalog-correct: leave the ~645 already-`LocalizedStringKey`-backed literal/interpolated sites untouched, and fix the ~431 pass-through sites that resolve to `Text`'s verbatim `StringProtocol` overload.

**Architecture:** `Text` has a `LocalizedStringKey`-typed initializer that plain and interpolated string literals resolve to automatically — those sites need zero code change. Sites passing a `String`-typed identifier, member access, function call, or ternary hit the verbatim overload instead. For each such site: if the underlying value is built from a literal template (an enum's `displayName`, a switch-of-literals helper, a ternary of two literals), wrap it in `String(localized:)` at its *definition*, not the `Text(x)` call. If the value is genuinely dynamic (user-entered text, a server error message, a person's name) with no literal template to key on, leave it unwrapped — wrapping adds no value pre-translation and collapses distinct content into a shared `"%@"` catalog key. This mirrors Phase 6a's `accessibilityLabel` migration exactly, with an added zero-touch bucket and an added skip-if-dynamic judgment call that 6a mostly resolved after the fact but this plan applies up front.

**Tech Stack:** Swift 5, SwiftUI, existing `xcodebuild` build/test commands, a one-off read-only Python census script (deleted after use).

## Global Constraints

- Repo root is not the Xcode project — all source paths are `TheRecruitingCompass/TheRecruitingCompass/...` (double-nested).
- Build: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
- Test: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests`
- Known flake: `RBSRequestErrorDomain Code=5` sim-launch crash mid-suite. If a test run stalls repeatedly at the same point, `xcrun simctl shutdown all && killall -9 CoreSimulatorService`, retry once; if it recurs identically, a machine restart clears it — don't burn more than 2 in-place retries.
- Baseline at plan-writing time: clean build, full unit suite `** TEST SUCCEEDED **` on branch `worktree-phase6b-localization` (worktree at `.claude/worktrees/phase6b-localization`).
- Commit after every task (feature batch) — small, reviewable, bisectable diffs.
- **Never wrap a value already wrapped in `String(localized:)` from Phase 6a** (e.g. a computed property shared between an `accessibilityLabel` and a `Text` call) — check the property's current body before editing it, not just the `Text(x)` call site.
- **Never wrap genuinely dynamic content** (error messages, server responses, user-entered text) — leave the pass-through as-is. This is a judgment call made by reading the value's source, not inferable from the call site alone.
- Out of scope: shipping a second language, running `xcodebuild -exportLocalizations` to seed the catalog (deferred, same as 6a), the already-correct literal/interpolated/`Text(verbatim:)`/`Text(date, style:)` buckets.

---

### Task 1: Build and run the Text() census script

**Files:**
- Create (temporary, delete in Step 4): `scripts/census-text-sites.py`

**Interfaces:**
- Produces: a per-file, per-line inventory of every `Text(...)` call site classified as `literal` (skip), `date-style`/`verbatim`/`image` (skip, edge case), or `passthrough` (candidate for Task 2-7). Later tasks re-run this script scoped to their own feature directories to get an authoritative, drift-free site list — do not hand-maintain a separate list.

- [ ] **Step 1: Write the census script**

Create `scripts/census-text-sites.py`:

```python
#!/usr/bin/env python3
"""Read-only census: classify every Text( call site in app source.
Run with an optional path filter: python3 scripts/census-text-sites.py [subdir ...]
"""
import re
import subprocess
import sys
import bisect

ROOT = "TheRecruitingCompass/TheRecruitingCompass"
CALL = re.compile(r'\bText\(')


def find_calls(text):
    """Yield (start_idx, arg_str) for each Text( call, matching balanced parens."""
    for m in CALL.finditer(text):
        i = m.end()
        depth = 1
        j = i
        while j < len(text) and depth > 0:
            if text[j] == '(':
                depth += 1
            elif text[j] == ')':
                depth -= 1
            j += 1
        yield m.start(), text[i:j - 1]


def classify(arg):
    s = arg.strip()
    if s.startswith('verbatim:'):
        return 'verbatim'
    if s.startswith('"'):
        return 'literal'
    if re.match(r'^[A-Za-z_][A-Za-z0-9_.]*\s*,\s*(style|format)\s*:', s):
        return 'date-style'
    if 'Image(' in s[:20]:
        return 'image'
    return 'passthrough'


def main():
    paths = sys.argv[1:] or [ROOT]
    result = subprocess.run(
        ["grep", "-rl", "Text(", *paths, "--include=*.swift"],
        capture_output=True, text=True,
    )
    files = sorted(f for f in result.stdout.splitlines() if f and '_ScreenTemplate' not in f)
    counts = {}
    passthrough_sites = []
    for path in files:
        with open(path, encoding='utf-8') as f:
            text = f.read()
        lines_start = [0]
        for idx, ch in enumerate(text):
            if ch == '\n':
                lines_start.append(idx + 1)

        def line_of(pos):
            return bisect.bisect_right(lines_start, pos)

        for start, arg in find_calls(text):
            bucket = classify(arg)
            counts[bucket] = counts.get(bucket, 0) + 1
            if bucket == 'passthrough':
                already = 'String(localized:' in arg
                passthrough_sites.append((path, line_of(start), arg.strip()[:80], already))
    print("=== Counts ===")
    for k, v in sorted(counts.items()):
        print(f"{k}: {v}")
    print("\n=== Passthrough sites (needing a decision), already-wrapped excluded ===")
    for path, line, arg, already in passthrough_sites:
        if not already:
            print(f"{path}:{line}: Text({arg}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run it against the whole app source**

Run: `python3 scripts/census-text-sites.py`

Expected output starts with:
```
=== Counts ===
date-style: 6
literal: 645
passthrough: 431
```
(verbatim/image counts, if any, print too — 0 of each is expected but not guaranteed; if either is nonzero, spot check a couple of those lines to confirm they're genuinely edge cases, not a `classify()` bug.)

- [ ] **Step 3: Sanity-check the passthrough count against Task 2-7's expected per-batch totals**

The full passthrough list should split by feature as: Family 16, Timeline 4, Legal 6, Landing 2, Settings 5, Profile 6, Onboarding 6, About 1 (Batch 1, Task 2, total 46) · CommunicationTemplates 7, ActivityFeed 6, Tasks 8, Notifications 6, Help 14, Analytics 15 (Batch 2, Task 3, total 56) · Interactions 26, Performance 15, Offers 38, Preferences 26 (Batch 3, Task 4, total 105) · Auth 22, Documents 26, Coaches 33, Events 38, Dashboard 21 (Batch 4, Task 5, total 140) · Schools 53 (Batch 5, Task 6) · Shared 31 (Batch 6, Task 7). If the script's per-feature counts (grep the output for `Features/<Name>`) drift more than a few sites from these numbers, treat the script's fresh output as authoritative (files change between plan-writing and execution) — do not force-match these totals.

- [ ] **Step 4: Do not delete the script yet**

Keep `scripts/census-text-sites.py` — Tasks 2-7 each re-run it scoped to their own feature directories at the start of their Step 1. It gets deleted in Task 8 (final close-out), not here.

- [ ] **Step 5: Commit**

```bash
git add scripts/census-text-sites.py
git commit -m "chore: add read-only Text() call-site census script

Classifies every Text(...) call site into literal/interpolated
(already LocalizedStringKey-backed, zero-touch), date-style/verbatim/
image (edge cases, skip), or passthrough (candidate for
String(localized:) wrap at its definition site). Re-run scoped to a
feature directory at the start of each migration batch task."
```

---

### Task 2: Migrate Batch 1 — Family, Timeline, Legal, Landing, Settings, Profile, Onboarding, About (46 sites)

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/About/Views/AboutView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Components/FamilyMemberCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Components/ParentFamilyCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Views/FamilyManagementParentView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Views/FamilyManagementPlayerView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Views/FamilyManagementView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Views/InviteJoinView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Family/Views/ParentOnboardingWizardView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Landing/Components/FeatureCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Legal/Components/LegalBodyText.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Legal/Components/LegalBulletList.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Legal/Components/LegalEmailLink.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Legal/Components/LegalSectionHeader.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Legal/Components/LegalSubsectionHeader.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Onboarding/Views/OnboardingView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Profile/Views/ProfileView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Settings/Views/SettingsView.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/PhaseCard.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/PhaseCardTaskRow.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Views/RecruitingTimelineView.swift`

**Interfaces:**
- Consumes: nothing from Task 1 except its census script (re-run, not modified).
- Produces: the worked classification rule every later batch task (3-7) applies. Read this task's Step 1 in full even if executing a later task — it's the only place the rule is spelled out with real examples.

- [ ] **Step 1: Re-run the census scoped to this batch and classify every site**

Run: `python3 scripts/census-text-sites.py TheRecruitingCompass/Features/Family TheRecruitingCompass/Features/Timeline TheRecruitingCompass/Features/Legal TheRecruitingCompass/Features/Landing TheRecruitingCompass/Features/Settings TheRecruitingCompass/Features/Profile TheRecruitingCompass/Features/Onboarding TheRecruitingCompass/Features/About`

For each `passthrough` line in the output, Read the file around that line, find where the passed value is *defined*, and classify into one of these four shapes. Concrete examples of each, found in this batch:

**Shape A — literal-template helper (switch/enum of string literals) → wrap at definition.**

`InviteJoinView.swift:80` calls `titleForError(error)`, a private function:
```swift
// Before
private func titleForError(_ error: InviteError) -> String {
  switch error {
  case .expired: return "This invite has expired"
  case .alreadyAccepted: return "Already connected"
  case .notFound: return "Invite not found"
  case .serverError: return "Something went wrong"
  }
}

// After
private func titleForError(_ error: InviteError) -> String {
  switch error {
  case .expired: return String(localized: "This invite has expired")
  case .alreadyAccepted: return String(localized: "Already connected")
  case .notFound: return String(localized: "Invite not found")
  case .serverError: return String(localized: "Something went wrong")
  }
}
```
The call site `Text(titleForError(error))` needs no change — it already receives a `String`, now a localized one.

`AboutView.swift:19` — `Text(subject.displayName)` where `subject: FeedbackSubject`. Find `FeedbackSubject`'s `displayName` definition (likely in its model file, not `AboutView.swift` — search `grep -rn "var displayName" TheRecruitingCompass/TheRecruitingCompass/Features/About` or wherever `FeedbackSubject` is declared) and wrap each case's literal return in `String(localized:)`, same pattern as `titleForError` above. If `displayName` is a raw-value `String` enum (`case bug = "Bug report"`) rather than a computed property with `return` statements, leave it as-is — raw values back `RawRepresentable` conformance and typically feed persistence/networking, not just display; wrapping a raw value changes its identity. Confirm which shape it is by reading the enum declaration before deciding.

`Settings/SettingsView.swift:270` — `Text(status.label)`. Same rule: find `status`'s type and its `label` property; if it's a computed property built from literals, wrap each branch; if it's a raw value, leave it.

**Shape B — ternary of two literals → wrap the ternary at the call site.**

`SettingsView.swift:52`:
```swift
// Before
Text(showCodeCopied ? "Copied!" : "Copy")
// After
Text(showCodeCopied ? String(localized: "Copied!") : String(localized: "Copy"))
```

`InviteJoinView.swift:401`:
```swift
// Before
Text(isLoading ? "Please wait..." : label)
```
Here only one branch is a literal — `label` is a parameter, not a literal. Read where `label` comes from at the call site (the view's initializer) to decide whether it's a literal-backed value (wrap both: `String(localized: "Please wait...")` / `String(localized: "\(label)")`) or truly dynamic (wrap only the literal branch, leave `label` as-is: `isLoading ? String(localized: "Please wait...") : label`). Check the call site — if `label` is passed a literal string when the view is constructed, treat it as Shape B; if it's passed a variable, treat the `label` half as Shape D (dynamic, leave alone) and only wrap the literal half.

**Shape C — number/date formatting via `String(_:)`, not a translatable string → no action.**

`ParentOnboardingWizardView.swift:160`, `OnboardingView.swift:154` — `Text(String(year))` where `year: Int`. This is `Int`'s `String(_:)` initializer producing a plain numeral (e.g. `"2027"`), not a template with translatable words. Leave unchanged.

**Shape D — genuinely dynamic content → leave unwrapped.**

`FamilyMemberCard.swift:25,32` — `Text(initials)` and `Text(displayName)`, where `displayName` is `member.user?.fullName ?? member.user?.email ?? "Unknown"`. This is a person's name or email — dynamic user data — with a literal `"Unknown"` fallback. Per the dynamic-content convention (a value that "carries the entire content" of the display, with at most an incidental literal fallback) leave both unwrapped.

`ParentFamilyCard.swift:8,12` — `Text(family.familyName)`, `Text(family.familyCode)` — user-entered/generated data. Leave unwrapped.

`FamilyManagementParentView.swift:138`, `FamilyManagementPlayerView.swift:183` — `Text(invite.invitedEmail)` — an email address. Leave unwrapped.

`FamilyManagementView.swift:23`, `ParentOnboardingWizardView.swift:18`, `OnboardingView.swift:248,365`, `ProfileView.swift:118,389` — `Text(error)` / `Text(zipError)` — error message strings, typically already assembled elsewhere (often already going through `localizedDescription` or a similar system-provided string). Leave unwrapped.

`InviteJoinView.swift:84` — `Text(error.errorDescription ?? "")` — same, dynamic, leave unwrapped.

`Legal/LegalBodyText.swift:7`, `LegalSectionHeader.swift:7`, `LegalSubsectionHeader.swift:7`, `LegalBulletList.swift:13` — these are reusable components where `text`/`item` is passed in as a `let` parameter from each call site. The component itself has no literal content — check whether **callers** pass literal strings (they do, for the legal-document body copy) or dynamic values. Since the component is generic infrastructure, leave the component's own `Text(text)` unwrapped (Shape D at this level) — the actual literal content lives at each call site, which is itself `Text`-free (the call site passes a string argument into `LegalBodyText(text: "...")`, not a `Text(...)` call the census script would even flag). No action needed here; these 4 sites are false-positive-shaped but correctly classified as "leave alone."

`ProfileView.swift:210` (`Text(email)`), `:239` (`Text(msg.text)`), `:477` (`Text(text)`), `:569` (`Text(initials)`) — dynamic user data / message text, same as above. Leave unwrapped.

`Landing/FeatureCard.swift:16,20` — `Text(title)`, `Text(description)` — reusable card component, parameters supplied by each call site (which contains the actual literal marketing copy, outside this component). Leave unwrapped at this component level, same reasoning as the Legal components above.

`Timeline/PhaseCard.swift:30,33` (`Text(phase.displayLabel)`, `Text(phase.theme)`), `PhaseCardTaskRow.swift:36` (`Text(task.title)`), `RecruitingTimelineView.swift:37` (`Text(headerTitle)`) — check each: `phase.displayLabel` if it's a computed property over a literal-cased enum is Shape A (wrap at definition); `phase.theme`, `task.title`, `headerTitle` if they're stored/dynamic content are Shape D (leave alone). Read each definition to decide — do not assume from the name alone.

`Settings/SettingsView.swift:39` (`Text(code)`), `:260` (`Text(title)`), `:281` (`Text(description)`) — `code` is the family join code (dynamic), `title`/`description` are parameters to a reusable row component fed by call sites — Shape D, leave unwrapped.

`FamilyManagementPlayerView.swift:56` (`Text(code)`), `ParentOnboardingWizardView.swift:130,145,227` (`Text(sport)`, `Text(pos)`, `Text(code)`) — sport/position names selected from a picker list and the family code — read the source: if `sport`/`pos` iterate over a literal array (`ForEach(sports, id: \.self) { sport in Text(sport) }` where `sports: [String]` is a literal array defined nearby), that array itself is the literal content — wrap the array's definition in `String(localized:)` per element, or if it's built from an enum, apply Shape A to the enum. If the array is loaded from data (not a literal Swift array), leave as Shape D.

- [ ] **Step 2: Apply the classification to every remaining un-discussed site in this batch's grep output**

The examples above cover the shapes present in this batch's 46 sites. Any site not explicitly named above follows the same four-shape decision tree: Read its definition, decide Shape A/B/C/D, act accordingly. Do not skip a site without having read its source.

- [ ] **Step 3: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors.

- [ ] **Step 4: Run affected unit tests**

Run: `grep -rl "FamilyMemberCard\|ParentFamilyCard\|InviteJoinView\|ParentOnboardingWizardView\|OnboardingView\|ProfileView\|SettingsView\|PhaseCard\|RecruitingTimelineView\|AboutView\|FeatureCard" TheRecruitingCompassTests --include="*.swift"`, then run those with `-only-testing:` (adjust target names to what the grep actually finds — if none exist for a given file, rely on Task 8's full-suite run).
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Family TheRecruitingCompass/TheRecruitingCompass/Features/Timeline TheRecruitingCompass/TheRecruitingCompass/Features/Legal TheRecruitingCompass/TheRecruitingCompass/Features/Landing TheRecruitingCompass/TheRecruitingCompass/Features/Settings TheRecruitingCompass/TheRecruitingCompass/Features/Profile TheRecruitingCompass/TheRecruitingCompass/Features/Onboarding TheRecruitingCompass/TheRecruitingCompass/Features/About
git commit -m "refactor: route Family/Timeline/Legal/Landing/Settings/Profile/Onboarding/About Text() literal-backed sites through String(localized:)"
```

---

### Task 3: Migrate Batch 2 — CommunicationTemplates, ActivityFeed, Tasks, Notifications, Help, Analytics (56 sites)

**Files:** discovered fresh in Step 1 (feature dirs listed below).

**Interfaces:**
- Consumes: the four-shape classification rule from Task 2, Step 1.
- Produces: nothing consumed by later tasks — each batch is independent.

- [ ] **Step 1: Re-run the census scoped to this batch and classify every site**

Run: `python3 scripts/census-text-sites.py TheRecruitingCompass/Features/CommunicationTemplates TheRecruitingCompass/Features/ActivityFeed TheRecruitingCompass/Features/Tasks TheRecruitingCompass/Features/Notifications TheRecruitingCompass/Features/Help TheRecruitingCompass/Features/Analytics`

For each `passthrough` line, Read the file, find the value's definition, and classify per Task 2 Step 1's four shapes (A: literal-template helper/enum → wrap at definition; B: ternary of literals → wrap at call site; C: numeral/date formatting → no action; D: genuinely dynamic → leave unwrapped). Apply the same care Task 2 used for reusable-component parameters (`Text(param)` inside a generic card/row component usually means the literal content lives at the *caller*, not this component — check callers before deciding, and if callers pass a mix of literal and dynamic content, this component-level site stays Shape D since it can't be uniformly localized at this level).

- [ ] **Step 2: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors.

- [ ] **Step 3: Run affected unit tests**

Run: `grep -rl "TemplateCard\|ActivityEventItem\|TaskCard\|NotificationCard\|HelpSectionHeader\|StatCardView\|FunnelChart\|PieChart\|ScatterChart" TheRecruitingCompassTests --include="*.swift"`, run those with `-only-testing:`; rely on Task 8 for anything not covered.
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/CommunicationTemplates TheRecruitingCompass/TheRecruitingCompass/Features/ActivityFeed TheRecruitingCompass/TheRecruitingCompass/Features/Tasks TheRecruitingCompass/TheRecruitingCompass/Features/Notifications TheRecruitingCompass/TheRecruitingCompass/Features/Help TheRecruitingCompass/TheRecruitingCompass/Features/Analytics
git commit -m "refactor: route CommunicationTemplates/ActivityFeed/Tasks/Notifications/Help/Analytics Text() literal-backed sites through String(localized:)"
```

---

### Task 4: Migrate Batch 3 — Interactions, Performance, Offers, Preferences (105 sites)

**Files:** discovered fresh in Step 1 (feature dirs listed below).

**Interfaces:**
- Consumes: the four-shape classification rule from Task 2, Step 1.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Re-run the census scoped to this batch and classify every site**

Run: `python3 scripts/census-text-sites.py TheRecruitingCompass/Features/Interactions TheRecruitingCompass/Features/Performance TheRecruitingCompass/Features/Offers TheRecruitingCompass/Features/Preferences`

Apply the four-shape rule from Task 2 Step 1 to every `passthrough` result. This is the largest single batch before Auth/Documents/Coaches/Events/Dashboard — work feature-by-feature (`Interactions`, then `Performance`, then `Offers`, then `Preferences`) and consider one sub-commit per feature if the diff grows large, running the build gate (Step 2) before each sub-commit rather than only once at the end.

- [ ] **Step 2: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors.

- [ ] **Step 3: Run affected unit tests**

Run: `grep -rl "InteractionCard\|OfferCard\|OfferSummaryCard\|LatestMetricCard\|PerformanceChartView\|ToggleCard\|PreferenceRow" TheRecruitingCompassTests --include="*.swift"`, run those with `-only-testing:`; rely on Task 8 for anything not covered.
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Interactions TheRecruitingCompass/TheRecruitingCompass/Features/Performance TheRecruitingCompass/TheRecruitingCompass/Features/Offers TheRecruitingCompass/TheRecruitingCompass/Features/Preferences
git commit -m "refactor: route Interactions/Performance/Offers/Preferences Text() literal-backed sites through String(localized:)"
```

---

### Task 5: Migrate Batch 4 — Auth, Documents, Coaches, Events, Dashboard (140 sites)

**Files:** discovered fresh in Step 1 (feature dirs listed below).

**Interfaces:**
- Consumes: the four-shape classification rule from Task 2, Step 1.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Re-run the census scoped to this batch and classify every site**

Run: `python3 scripts/census-text-sites.py TheRecruitingCompass/Features/Auth TheRecruitingCompass/Features/Documents TheRecruitingCompass/Features/Coaches TheRecruitingCompass/Features/Events TheRecruitingCompass/Features/Dashboard`

Apply the four-shape rule from Task 2 Step 1. This is the largest batch (140 sites) — work feature-by-feature and sub-commit per feature (`Auth`, `Documents`, `Coaches`, `Events`, `Dashboard`), running the build gate before each sub-commit.

- [ ] **Step 2: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors.

- [ ] **Step 3: Run affected unit tests**

Run: `grep -rl "LoginView\|SignupView\|DocumentCard\|CoachCard\|EventCard\|DashboardView" TheRecruitingCompassTests --include="*.swift"`, run those with `-only-testing:`; rely on Task 8 for anything not covered.
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Auth TheRecruitingCompass/TheRecruitingCompass/Features/Documents TheRecruitingCompass/TheRecruitingCompass/Features/Coaches TheRecruitingCompass/TheRecruitingCompass/Features/Events TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard
git commit -m "refactor: route Auth/Documents/Coaches/Events/Dashboard Text() literal-backed sites through String(localized:)"
```

---

### Task 6: Migrate Batch 5 — Schools (53 sites, largest single feature)

**Files:** discovered fresh in Step 1.

**Interfaces:**
- Consumes: the four-shape classification rule from Task 2, Step 1.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Re-run the census scoped to this batch and classify every site**

Run: `python3 scripts/census-text-sites.py TheRecruitingCompass/Features/Schools`

Apply the four-shape rule from Task 2 Step 1, file by file. Consider 2-3 sub-commits by subdirectory (e.g. `Schools/Views` then `Schools/Components`) if the diff grows unwieldy, running the build gate before each sub-commit.

- [ ] **Step 2: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors.

- [ ] **Step 3: Run affected unit tests**

Run: `grep -rl "School" TheRecruitingCompassTests --include="*.swift" | grep -i school`, run with `-only-testing:`.
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Schools
git commit -m "refactor: route Schools Text() literal-backed sites through String(localized:)"
```

---

### Task 7: Migrate Batch 6 — Shared/Components (31 sites, cross-feature)

**Files:** discovered fresh in Step 1.

**Interfaces:**
- Consumes: the four-shape classification rule from Task 2, Step 1.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Re-run the census scoped to this batch and classify every site**

Run: `python3 scripts/census-text-sites.py TheRecruitingCompass/Shared`

Apply the four-shape rule from Task 2 Step 1, with extra care: these are reusable components used across many features, so a `Text(param)` site is very likely Shape D (the literal content lives at each of many call sites, not in the component itself) unless the component's own file defines the value from a literal-cased enum or a switch. Read each file fully before editing — a mistake here affects every feature that uses the component.

- [ ] **Step 2: Build**

Run: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors.

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Shared
git commit -m "refactor: route Shared/Components Text() literal-backed sites through String(localized:)"
```

---

### Task 8: Full-suite verification and close-out

**Files:**
- Delete: `scripts/census-text-sites.py`

**Interfaces:**
- Consumes: all prior tasks' committed changes.

- [ ] **Step 1: Full clean build**

Run: `cd TheRecruitingCompass && xcodebuild clean build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: no new errors or warnings beyond the pre-existing baseline.

- [ ] **Step 2: Full unit test suite**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests`
Expected: `** TEST SUCCEEDED **`, same pass count as this plan's baseline (confirm the current count against `main`'s latest known-good count, adjusting only for tests added/removed since).

- [ ] **Step 3: Confirm no remaining un-classified sites**

Run: `python3 scripts/census-text-sites.py`

Expected: the `passthrough` count only includes sites that were deliberately left unwrapped as Shape C (numeral/date, no action needed) or Shape D (dynamic content, no action needed) per Tasks 2-7's classification — not sites nobody looked at. If any batch's actual pass count doesn't match what Tasks 2-7 recorded touching, go back and account for the gap before closing out.

- [ ] **Step 4: Delete the census script**

Its one-off purpose (guiding this migration) is done; keeping it risks becoming stale/misleading for future audits rather than being re-validated and rerun deliberately.

Run: `rm scripts/census-text-sites.py`

- [ ] **Step 5: Update project memory**

Update `CLAUDE.local.md` (worktree copy) and `MEMORY.md` (if used) to record: Phase 6b complete — ~641 literal/interpolated `Text()` sites already catalog-backed (no change needed), ~431 pass-through sites classified and fixed (literal-template sites wrapped in `String(localized:)`, genuinely dynamic sites deliberately left unwrapped per the Shape D convention). Master plan file `planning/2026-08-02-ios-audit-remediation-plan.md` still missing — flag for a future session to either recreate or formally retire the reference.

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "chore: Phase 6b complete — Text() call-site localization verified

Full clean build + unit suite green. ~641 literal/interpolated Text()
sites confirmed already LocalizedStringKey-backed (zero-touch, unlike
6a's accessibilityLabel sites). ~431 pass-through sites classified:
literal-template values (enum displayName, switch-of-literals
helpers, ternary-of-literals) wrapped in String(localized:) at their
definition site; genuinely dynamic values (error messages,
user-entered text, person/email/school names) deliberately left
unwrapped per the same dynamic-content convention 6a established.
Census script removed after use — its one-off purpose is complete."
```
