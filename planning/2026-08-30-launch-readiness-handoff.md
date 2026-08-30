# Launch Readiness Handoff — 2026-08-30

## What happened (session 1 — planning)

Exhaustive feature inventory of both iOS and web repos → 6 parallel workstreams producing plans for App Store launch, marketing, and platform improvements.

## What happened (session 2 — quick wins)

Locked all 8 open questions, then shipped 3 quick wins across both platforms:

### Shipped
| Commit | Repo | What |
|--------|------|------|
| `a72b8af4` | iOS main | fix(help): fit-score→fit-signals + parent-edit callouts (2 files, 14 edits) |
| `0c17b03b` | iOS main | chore: TARGETED_DEVICE_FAMILY=1 (iPhone-only for launch) |
| `a2d58bee` | web develop | fix(help): fit-score→fit-signals + parent-edit callouts (6 files, 17 edits) |
| `6659d0f2` | web develop | fix: remove assertNotParent guard on player-details.patch.ts |

### GitHub Issues Created
| # | Repo | Title |
|---|------|-------|
| [#79](https://github.com/candrikanich/recruiting-compass-ios/issues/79) | iOS | Platform Parity (4-phase, 11–15 weeks) |
| [#80](https://github.com/candrikanich/recruiting-compass-ios/issues/80) | iOS | Business Plan Update |
| [#81](https://github.com/candrikanich/recruiting-compass-ios/issues/81) | iOS | Marketing Copy |
| [#82](https://github.com/candrikanich/recruiting-compass-ios/issues/82) | iOS | App Store Submission |
| [#83](https://github.com/candrikanich/recruiting-compass-ios/issues/83) | iOS | Help Center Update (Phase 0 shipped, expansion remaining) |
| [#84](https://github.com/candrikanich/recruiting-compass-ios/issues/84) | iOS | Landing Page Content |
| [#554](https://github.com/candrikanich/recruiting-compass-web/issues/554) | web | Parent edit server block (FIXED) |
| [#555](https://github.com/candrikanich/recruiting-compass-web/issues/555) | web | Audit remaining assertNotParent guards |

### Published Artifacts
1. **Feature Inventory** — https://claude.ai/code/artifact/c2c97195-b2d9-4078-9382-6f6af3fe148d
   Complete feature catalog across iOS + web (22 sections, platform badges, stats)
2. **Launch Readiness Dashboard** — https://claude.ai/code/artifact/86a3b131-13d5-4453-9650-343696d74328
   Consolidated status of all 6 workstreams with expandable details + action items

### Plans Created (all in `planning/`)

| File | Summary |
|------|---------|
| `platform-parity-plan.md` | 10 iOS gaps, 4 web gaps. 4-phase plan, 11–15 weeks. Phase 1: GDPR export + School Map (2–3 wks). Phase 2: Deadlines + Rec Letters + School Recs (3–4 wks). Phase 3: Advanced Search + Reports (4–6 wks). Phase 4: Polish + export + extra widgets (2 wks). |
| `business-plan-update-recommendations.md` | Original docs (Jan 2026) = baseball-only web MVP. Product = 19-sport dual-platform beyond V2.0 roadmap. Fit Score never built (Personal Fit Signals instead). $12/$25 pricing never implemented. TAM 3–5× larger. 5 priorities: Product Capabilities doc → exec summary → competitive matrix → Monetization v2 → market research. |
| `marketing-copy.md` | 10 taglines, App Store listing (subtitle + 4000-char desc + keywords), 30 social posts (IG/X/FB/TikTok), 12 feature highlight cards, value props (player/parent/family), competitive differentiators vs NCSA/FieldLevel/SportsRecruits/CaptainU + 7 unique advantages. |
| `app-store-submission-plan.md` | Full checklist. Codebase ready: COPPA, account deletion, privacy manifest, push, ATS, associated domains. 9 action items for Chris (public privacy policy URL, support URL, App Store Connect record, demo account, iPad verification, app icon, screenshots, AASA file, privacy nutrition label). ~9-day launch timeline. |
| `help-center-update-plan.md` | Current: 4 sections, ~20 articles, last reviewed Feb 2026. iOS has STALE fit-score content (misleading). Plan: 4→7 sections, ~34 articles, ~10,200 words. Immediate fix: iOS fit-signal error + stale family-edit callout. |
| `landing-page-content-update.md` | Both platforms' landing pages show ~5% of value (logo + 3 vague cards). Full new copy: hero, 6 feature cards, How It Works, player vs parent sections, 19-sport grid, 10 FAQs, CTA. Core positioning: "No recruiting service required." |

---

## Decisions Locked (2026-08-30)

| # | Question | Decision |
|---|----------|----------|
| 1 | External beta | Manual dogfooding (Chris + son). No formal external beta yet — flushing out happy path first. |
| 2 | Monetization | Single price tier at launch (amount TBD). Original $12/$25 tiers scrapped. |
| 3 | iPad support | iPhone-only for App Store launch (`TARGETED_DEVICE_FAMILY = 1`). iPad = stretch goal Chris will explore pre-launch; not a blocker. |
| 4 | iOS advanced search | Direct Supabase queries (matches web pattern, no API proxy layer). |
| 5 | Mobile reports | Per-feature export via share sheets. No unified Reports page. |
| 6 | Priority order | School recommendations first, then deadlines tracker. |
| 7 | Help screenshots | Real screenshots in help articles. |
| 8 | Contextual help links | Yes — in-app feature→help article deep links. |

---

## Key Findings the Next Session Should Know

### Critical Issues
- ~~**Help center iOS has misleading content**~~ — **FIXED** (session 2). Fit-score→fit-signals + parent-edit callouts updated on both platforms.
- **Landing pages underselling ~95%** of product value. Both platforms = logo + 2 buttons + 3 vague cards.
- **Business plan describes a different product** — baseball-only, web-only MVP. Needs full rewrite.
- **$0 revenue** — no monetization implemented despite $12/$25 tiers in original plan.
- **8 endpoints still block parent actions** — `assertNotParent` guards on video-links, phase-advance, school-enrich, suggestions. Tracked in web #555.

### Ready to Go (App Store)
- COPPA age gate ✓
- Account deletion (30-day grace) ✓
- Privacy manifest (no tracking) ✓
- Push notification entitlement ✓
- Terms + Privacy Policy (native views) ✓
- App Transport Security ✓
- Associated domains ✓

### Product by the Numbers
- 19 sports supported
- 33+ outreach templates with NCAA compliance
- 66+ sport-specific metric definitions
- 22 NCAA recruiting calendar keys
- 5-stage recruiting pipeline
- 126+ automated tests
- 9 server-side cron jobs

---

## Suggested Next Steps

1. ~~**Fix misleading help content**~~ — **DONE** (session 2)
2. **Implement landing page** — biggest ROI for user acquisition. Copy is written. → Issue #84
3. **App Store submission** — address 9 action items (Chris), capture screenshots, submit. → Issue #82
4. **Audit assertNotParent guards** — decide per-endpoint parent permissions. → Web #555
5. **Business plan rewrite** — update docs in `/Volumes/AlphabetSoup/TheRecruitingCompass/documents/`. → Issue #80
6. **Help center expansion** — 4→7 sections, write 14 new articles. → Issue #83
7. **Platform parity Phase 1** — GDPR export + School Map Widget (2–3 weeks). → Issue #79
8. **Social media launch** — 30 posts ready, schedule rollout. → Issue #81

---

## Repo State (after session 2)
- **iOS branch:** `main` @ `0c17b03b` (pushed)
- **Web branch:** `develop` @ `6659d0f2` (pushed)
- **iOS build:** Clean (xcodebuild exit 0)
- **Web build:** Clean (vue-tsc + eslint clean)
- **Uncommitted:** `planning/*.md` files (6 plans + this handoff) — not tracked
- **Business plan docs location:** `/Volumes/AlphabetSoup/TheRecruitingCompass/documents/`
- **Web repo:** `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web`
