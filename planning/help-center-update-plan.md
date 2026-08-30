# Help Center Update Plan

**Date:** 2026-08-29
**Last reviewed (current content):** February 2026 — 6 months stale
**Status:** Planning

---

## 1. Current State

Both platforms have identical 4-section structure with near-identical content:

| Section | Topics Covered |
|---|---|
| Getting Started | What is TRC, profile creation, family invite, dashboard overview, first action |
| Schools & Coaches | Adding schools, fit scores/signals, list management, logging interactions, interaction types |
| Phases & Letters | Phase overview, 4 phases, advancement, rec letter request, letter status tracking |
| Account & Settings | Profile updates, family management, notifications, password, data/privacy |

### Platform Differences Found

| Item | iOS (SwiftUI) | Web (Vue) |
|---|---|---|
| Fit scores | **STALE** — still says "fit score 0–100" with 4 dimensions (academic, athletic, size, location) | **Correct** — updated to "fit signals" (Personal Fit + Academic Fit), with callout that athletic/opportunity fit are not shown |
| Navigation links | Plain text references | Inline `<NuxtLink>` to /search, /schools, /documents, /settings |
| Sort options | "by fit score, recent activity, or date added" | "by recent activity or date added" (no fit score sort) |

**Critical:** iOS help content references the old fit-score system that was replaced by Personal Fit Signals months ago. This is actively misleading users.

---

## 2. Gap Analysis — Features with Zero Help Coverage

These shipped features have NO documentation in either platform's help center:

| Feature | Ships On | Priority | Why It Needs Help |
|---|---|---|---|
| **Dashboard Widgets** (9 configurable, reorder, show/hide) | Both | HIGH | Users don't know they can customize; most visible surface |
| **Recruiting Pipeline** (5-stage school status stepper) | Both | HIGH | Core workflow change; replaces old status dropdown |
| **Quick Comm / Templates** (33 templates, NCAA compliance) | Both | HIGH | Complex feature with guardrails users need to understand |
| **NCAA Recruiting Calendar** (sport-specific periods) | Both | HIGH | Users need to know what Dead/Quiet/Contact/Eval periods mean |
| **Public Profile** (create, share, QR, Send Profile, view tracking) | Both | HIGH | Revenue/engagement driver; users need setup guidance |
| **Performance Metrics** (sport-specific logging, primary metric) | Both | MEDIUM | 17 sports × multiple metrics; users need to know what to log |
| **Video Links** (highlight reels, management) | Both | MEDIUM | Important for recruiting but straightforward |
| **Action Items / Suggestions** (AI-driven suggestions engine) | Both | MEDIUM | Users wonder where suggestions come from |
| **Events & Offers** (event management, offer tracking, comparison) | Both | MEDIUM | Core recruiting workflow |
| **Analytics** (charts, engagement data, follow-up tracking) | Both | MEDIUM | Users need to understand what the numbers mean |
| **Family System** (parent dashboard, multi-athlete, permissions) | Both | LOW | Existing content is thin; needs expansion, not new section |

---

## 3. Proposed New Structure

The 4-section model can't hold 15+ feature areas. Restructure to **7 sections**:

### New Section Architecture

| # | Section | Slug | Content |
|---|---|---|---|
| 1 | **Getting Started** | `getting-started` | What is TRC, profile setup, family invite, first steps (KEEP, minor updates) |
| 2 | **Your Dashboard** | `dashboard` | **NEW** — widgets, customization, action items, analytics overview |
| 3 | **Schools & Pipeline** | `schools` | **EXPANDED** — adding schools, fit signals (FIXED), pipeline stages, school detail |
| 4 | **Coaches & Outreach** | `coaches` | **NEW** — coach interactions, Quick Comm templates, NCAA compliance, contact windows |
| 5 | **Your Recruiting Profile** | `profile` | **NEW** — public profile, Send Profile, QR code, video links, performance metrics |
| 6 | **Calendar & Timeline** | `calendar` | **RENAMED** from "Phases & Letters" — NCAA calendar, timeline tasks/guidance, milestones, events & offers |
| 7 | **Account & Settings** | `account` | Family management (expanded), notifications, password, data/privacy (KEEP, expand family) |

**Rationale:** "Phases & Letters" is the weakest section — phases are a minor concept vs. the NCAA calendar and timeline that actually drive daily use. "Schools & Coaches" splits into two because coach outreach (Quick Comm, templates, compliance) is a big enough topic on its own. Public profile + metrics + video are all "your recruiting presence" — one section.

---

## 4. Content Plan — Article-by-Article

### Section 1: Getting Started (UPDATE)

| Article | Action | Changes |
|---|---|---|
| What is TRC? | Minor update | Add mention of 19 sports, NCAA calendar, outreach templates |
| Creating your profile | Update | Add sport + gender selection (drives calendar), mention multi-sport |
| Adding family members | Keep | Minor wording refresh |
| Understanding the dashboard | **Rewrite** | Move to Section 2; replace generic description with widget list |
| Your first action | Update | Mention pipeline stages, not just "add schools" |

**Est:** ~800 words (down from ~1000; moved dashboard content out)

### Section 2: Your Dashboard (NEW)

| Article | Content |
|---|---|
| Dashboard overview | 9 widgets listed with what each shows |
| Customizing your dashboard | How to reorder widgets, show/hide, restore defaults |
| Action Items | What suggestions are, how they're generated, dismiss vs. complete |
| Analytics snapshot | What the charts mean (interactions over time, school engagement, follow-up rate) |

**Est:** ~1200 words

### Section 3: Schools & Pipeline (EXPANDED)

| Article | Action | Content |
|---|---|---|
| Adding a school | Keep | Minor refresh |
| School Fit Signals | **Rewrite (iOS)** / Keep (web) | Personal Fit (location/campus/cost) + Academic Fit (SAT/ACT range). Remove stale 0–100 score and 4-dimension breakdown from iOS. |
| Recruiting Pipeline | **New** | 5 stages (Researching → Contacted → Visiting → Offer Received → Committed), auto-advance on interaction, pipeline stepper UI, "Not Pursuing" off-ramp |
| Managing your school list | Update | Add pipeline filter, remove stale "sort by fit score" from iOS |
| School detail page | **New** | What you see on a school page — coaches, interactions, fit signals, distance from home, personal fit breakdown |

**Est:** ~1500 words

### Section 4: Coaches & Outreach (NEW)

| Article | Content |
|---|---|
| Adding and managing coaches | How coaches appear on school pages, adding a coach, coach detail view (tags, source, channels, insights) |
| Logging interactions | Move from Schools section; expand with sentiment, direction (inbound/outbound) |
| Quick Comm templates | What templates are, how to pick one, token replacement, variable panel |
| NCAA compliance & contact windows | What contact windows are, how the app enforces them, anti-spam guardrails |
| Sending messages | Email/text/social compose flow, Send Profile integration |

**Est:** ~1800 words

### Section 5: Your Recruiting Profile (NEW)

| Article | Content |
|---|---|
| Public Profile | What it is, how to create/edit, what coaches see, privacy controls |
| Sharing your profile | Send Profile (email/text compose with boilerplate), copy link, QR code |
| Tracking profile views | View statistics, who viewed, when |
| Video Links | Adding/managing highlight reels, where they appear |
| Performance Metrics | Logging sport-specific stats, setting primary metric, metric history, how {{carryingTool}} works in templates |

**Est:** ~1500 words

### Section 6: Calendar & Timeline (RENAMED/REWRITTEN)

| Article | Action | Content |
|---|---|---|
| NCAA Recruiting Calendar | **New** | What Dead/Quiet/Contact/Evaluation periods mean; how to read the calendar widget; sport-specific calendars; gender filtering |
| Timeline Tasks | **New** | What tasks are, how they're generated, actionable vs. informational, task sorting |
| Timeline Guidance | **New** | The 5 guidance panels (SAT/ACT milestones, Common Worries, What Matters, etc.) |
| Events & Offers | **New** | Creating events, tracking offers, offer comparison, campus visit scheduling |
| Upcoming Milestones | **New** | What milestones are (signing dates, NCAA deadlines), how they appear on the calendar widget |
| ~~Phases overview~~ | **Remove/fold** | Phase concept folded into Timeline Tasks as context; the 4-phase model is not how the app actually works anymore |
| ~~Recommendation letters~~ | **Keep but relocate** | Move to Account section or keep in Timeline; it's a minor feature |

**Est:** ~2000 words

### Section 7: Account & Settings (UPDATE)

| Article | Action | Content |
|---|---|---|
| Updating your profile | Update | Reference sport/gender selection, positions, multi-sport |
| Family system | **Expand** | Parent dashboard view, what parents can see/do, multi-athlete families, how family creation works |
| Notifications | Update | Add offer/inbound/event notification types (shipped 2026-08) |
| Password | Keep | No change |
| Data & privacy | Keep | No change |
| Rec letter tracking | **Move here** | From old Phases section; minor feature, fits better in settings/management |

**Est:** ~1200 words

---

## 5. Platform-Specific Notes

| Topic | iOS-Specific | Web-Specific |
|---|---|---|
| Navigation references | "Go to Schools tab" / "Tap the gear icon" | Inline links to `/schools`, `/settings`, etc. |
| Quick Comm compose | `.sheet` presentation, native share sheet | Modal dialog, mailto:/sms: links |
| Public Profile QR | Native QR generation | Browser-based QR |
| Push notifications | APNs setup, notification preferences in Settings app | Browser notification permission |
| Dashboard widget reorder | Drag handle in widget list | Drag-and-drop in widget grid |
| NCAA Calendar | Sport/gender picker in widget | Sidebar filter |

**Implementation note:** Content substance must be identical. Only interaction verbs ("tap" vs "click") and navigation paths differ. The web can use `<NuxtLink>` for in-app links; iOS uses plain text references.

---

## 6. Content to Fix Immediately (Pre-Restructure)

These are factual errors in the current help content that should be fixed even before the full restructure:

1. **iOS fit scores (WRONG):** Still says "fit score 0–100" with academic/athletic/size/location. Must update to Personal Fit Signals (location/campus/cost) + Academic Fit. Web already correct.
2. **iOS sort options (WRONG):** Lists "sort by fit score" — this option doesn't exist anymore.
3. **Both — "Last reviewed: February 2026":** 6 months stale; update to current date on any edit.
4. **iOS — family callout (STALE):** Says "only the athlete can make changes to the profile" — parents can now edit the athlete's profile (family-shared player profile shipped 2026-08-09).

---

## 7. Effort Estimate

| Work Item | Articles | Est. Words | Effort |
|---|---|---|---|
| Fix immediate errors (iOS fit signals, family) | 2 updates | ~200 | 1 hour |
| Section 1: Getting Started (refresh) | 4 articles | ~800 | 2 hours |
| Section 2: Dashboard (new) | 4 articles | ~1200 | 3 hours |
| Section 3: Schools & Pipeline (expand) | 5 articles | ~1500 | 3 hours |
| Section 4: Coaches & Outreach (new) | 5 articles | ~1800 | 4 hours |
| Section 5: Recruiting Profile (new) | 5 articles | ~1500 | 3 hours |
| Section 6: Calendar & Timeline (rewrite) | 5 articles | ~2000 | 4 hours |
| Section 7: Account & Settings (update) | 6 articles | ~1200 | 2 hours |
| **Total** | **~34 articles** | **~10,200 words** | **~22 hours** |

Current: 4 sections, ~20 articles, ~4,500 words
New: 7 sections, ~34 articles, ~10,200 words

### Implementation Order

1. **Phase 0 (immediate):** Fix iOS fit-signal and family-edit errors — these are actively wrong
2. **Phase 1:** New sections 2 + 3 (Dashboard + Schools/Pipeline) — highest user impact
3. **Phase 2:** New sections 4 + 5 (Coaches/Outreach + Profile) — biggest content gaps
4. **Phase 3:** Section 6 (Calendar/Timeline) — complex but lower urgency
5. **Phase 4:** Section 1 + 7 updates, old content cleanup, "last reviewed" dates

---

## 8. Technical Changes Required

### iOS
- `HelpSection` enum: add `.dashboard`, `.coaches`, `.profile`, `.calendar` cases; rename `.phases` → `.calendar`; update slugs, titles, descriptions, icons
- `HelpSectionDetailView`: add content views for new sections
- Consider breaking monolithic `HelpSectionDetailView.swift` into per-section files (it's already 400+ lines and will triple)

### Web
- Add new page files: `dashboard.vue`, `coaches.vue`, `profile.vue`, `calendar.vue`
- Rename `phases.vue` → `calendar.vue` (add redirect from old URL)
- Update `index.vue` section list
- Update help layout sidebar if one exists

### Both
- Update `lastReviewed` / "Last reviewed" to current date
- Add help center deep-link support if not present (for in-app "?" buttons linking to specific articles)

---

## 9. Open Questions

1. **Should rec letters stay or go?** The feature exists but seems lightly used. Could fold into Account or drop entirely.
2. **In-app contextual help?** Should features link to their help article (e.g., "?" icon on the NCAA Calendar widget linking to `/help/calendar`)? This would increase discoverability significantly.
3. **Screenshots/images:** Current help uses `HelpImageSlot` placeholders with captions but no actual images. Should we add real screenshots? If so, that's a separate asset-creation effort.
4. **Search:** Neither platform has help search. Worth adding as the content triples in size?
