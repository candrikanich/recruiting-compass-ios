---
name: platform-parity
description: Keep the web app and the iOS app feature-, UX-, data-, and behavior-symmetric. Use when adding, removing, renaming, or restyling a field, data pill, section, action, template, or option set on either platform, when the user says "add it to the web too", "add it back on iOS too", "replicate the iOS app on the web", "maintain parity", "is iOS in sync with web?", or when a display, ordering, or missing-action bug is found on one platform.
---

# Web <-> iOS Parity

Repos: `recruiting-compass-web` and `recruiting-compass-ios`. Chris treats them as one product. A change that lands on only one platform is incomplete work, not a finished task.

Parity flows both directions. iOS is often the reference implementation ("replicate the iOS app on the web"), web is sometimes the reference. Ask which platform is the source of truth for the layout only if the request doesn't say.

Parity is the acceptance bar ("as long as this maintains parity with the web process, I approve"). Verify it before reporting done - don't ask whether the other platform is in scope.

## Same-pass rule

When a field, data pill, section, action, template list, or option set changes on one platform:

1. Locate the equivalent screen on the other platform before writing code.
2. Apply the same change there in the same pass.
3. Commit and push both repos in the same turn (Chris says "commit both and push both").
4. If the other platform is not editable from this session, produce a handoff spec instead - use the `web-to-ios-handoff` skill - and say explicitly that the other platform is still pending.

Don't ask whether to also do the other platform. Do it, then report both.

## What must match

- **Capability set**: the *full* set of actions, not a working subset. If web can share **and unshare**, iOS does both. If the web modal offers every message template, the iOS sheet offers every template - an empty or trimmed list is a parity bug, not a smaller feature.
- **Sections**: same set, same names, same order, same edit-vs-lookup behavior. Example landed state for school detail: two sections under the map on both platforms - `Contact & Social` (editable) and `College Data` (lookup). Grouping matters too: where web nests `Academic Fit` + `Personal Fit` inside a `School Fit` section, iOS nests them the same way, including the same missing-data lookup link.
- **Fields**: same fields present in each section. A new field lands on both platforms, in the same section on each. A field missing on one platform is a bug on that platform.
- **Data pills**: same pills, same placement (e.g. the school title header carries the pills; a sidebar status section shows title + control only).
- **Option sets / enums**: identical across platforms. When the two differ, **adopt the richer set and widen the simpler one** - never narrow the richer platform to match a simplified list.
- **Displayed values**: render the complete assembled value, not a partial one. Concrete case: the line under a school name is the full assembled school address (street, city, state, zip), not a campus-address fragment.
- **Behavior, not just render**: the same list sorts in the same order on both platforms and for every role (a parent on iOS and a player on web see the same order). The same tile navigates to the same detail screen. Badges/derived state (e.g. overdue) compute from the same data on both sides.

## Parity runs both directions, including deletions

- iOS-only UI ports to web (fit-score pill on the school tile, static status pill + `Recruiting Status` section).
- Web-only UI ports to iOS.
- **When web intentionally omits a section, remove it from iOS** rather than leaving iOS ahead. Check the iOS section list against web before keeping a section; parity means matching the section set, not only adding what's missing.

## Platform-idiomatic container, identical content

Matching UX does not mean matching chrome. iOS uses a native sheet where web uses a modal; that's correct. What's inside - actions, templates, fields, copy - must be identical.

## Before reporting done

- [ ] Both platforms changed, or a handoff spec written and the gap named
- [ ] Section list, field list, action list, and option set diffed platform-to-platform, not just eyeballed on one
- [ ] Sort order and navigation destinations compared across platforms **and roles**
- [ ] Sections web omits are gone from iOS; iOS-only elements ported to web
- [ ] Assembled/composite values render in full on both
- [ ] Build verified per platform (`npx tsc --noEmit` for web, `xcodebuild build -quiet` for iOS)
- [ ] Report states what shipped on web, what shipped on iOS, and what is left
