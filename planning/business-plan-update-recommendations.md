# Business Plan Update Recommendations

**Date:** 2026-08-29
**Scope:** All documents in `/documents/` — business plan, PRDs, market research, personas, beta launch materials
**Purpose:** Align documentation with the product that was actually built

---

## Executive Summary

The business plan documents were written January 2026 for a **baseball-only, web-only MVP** planned for a 90-day build. Eight months later, the product is a **19-sport, dual-platform (iOS + web) recruiting operating system** with features that surpass the original V2.0 roadmap. The documents are now significantly behind the product in scope, positioning, and technical reality.

The original vision — "a recruiting field guide that helps athletes understand and own the process" — remains valid and should be preserved. But the competitive positioning, feature descriptions, market sizing, roadmap, and technical architecture sections need wholesale rewriting.

---

## Document Inventory & Status

| Document | Status | Action Needed |
|----------|--------|---------------|
| Business Plan (internal) | **Heavily outdated** | Rewrite most sections |
| Business Plan Review | **Outdated** — many identified gaps have been addressed | Update "gaps" section to reflect current state |
| TRC PRD (sport-agnostic version) | **Partially current** — core philosophy holds, features lag | Major feature update, architecture rewrite |
| COMPASS PRD (baseball version) | **Obsolete** — baseball-only, pre-rename | Archive; redirect to TRC PRD |
| Market Research Report | **Still relevant** — pain points validated by product | Add multi-sport market data, update competitor info |
| User Personas | **Still relevant** — segments hold | Remove baseball-only framing, add sport-agnostic examples |
| Beta Launch materials | **Status unclear** — was the beta executed? | Update or archive |
| Tips/Tricks/Actions | **Evergreen content** | Minor sport-agnostic edits |

---

## Section-by-Section Recommendations

### 1. EXECUTIVE SUMMARY — Rewrite Required

**Original (Business Plan):**
> "This app is a sport-agnostic recruiting guide... The MVP is currently in development, with a targeted launch window of 3-6 months."

**Recommended replacement:**
> The Recruiting Compass is a dual-platform recruiting operating system (iOS native + web) that helps high school athletes and their families navigate college recruiting across 19 sports. The product combines a lightweight CRM for schools and coaches, NCAA-compliant communication tools, a 4-year task-based recruiting timeline, and an intelligence engine that surfaces personalized action items. It ships on iOS (SwiftUI/Supabase) and web (Nuxt/Supabase) with cross-platform feature parity, WCAG AA accessibility, and a Supabase backend with Row-Level Security and 9 scheduled cron jobs. The product is in active development with a working beta; monetization has not yet launched.

**Why:** The original reads as a pre-build pitch. The product now exists and has substantial functionality. The summary should reflect what's real.

---

### 2. PRODUCT OVERVIEW — Major Rewrite Required

The PRDs describe a product that is roughly at the Phase 3-4 level of the original roadmap. The actual product has blown past V2.0. Here is what was planned vs. what was built:

#### 2a. Sport Support

**Original:** "Initial Focus: Baseball, with expansion to other sports"
**Actual:** 19 sports supported — baseball, softball, football, men's/women's basketball, men's/women's soccer, volleyball, men's/women's lacrosse, men's/women's swimming/diving, men's/women's tennis, men's/women's golf, men's/women's track & field, wrestling, gymnastics, beach volleyball. Each sport has its own metric definitions, position registry, recruiting calendar keys, and laterality handling.

**Recommendation:** Replace all baseball-specific language with sport-agnostic framing. The 19-sport registry is a core differentiator and should be featured prominently.

#### 2b. Platform

**Original:** "Tech Stack: Nuxt + Supabase" (web-only)
**Actual:** Dual-platform — native iOS (SwiftUI) + web (Nuxt 3), sharing a Supabase backend. iOS app is on TestFlight. Cross-platform parity is actively maintained.

**Recommendation:** Add "Native Mobile" as a core platform capability, not a future roadmap item. Update tech stack to reflect iOS (Swift/SwiftUI) alongside Nuxt.

#### 2c. Schools Management

**Original PRD:** School database with 3,000+ programs, A/B/C priority tiers, status tracking (Interested/Contacted/Camp Invite/Recruited/Official Visit/Offer/Committed/Not Pursuing), numeric Fit Score (0-100, 4-component weighted algorithm).

**Actual:**
- College Scorecard enrichment (real institutional data, not just a name database)
- 5-stage recruiting pipeline: Researching → Contacted → Visiting → Offer Received → Committed (with Not Pursuing off-ramp)
- Interactive pipeline stepper UI (replaces dropdown)
- Personal Fit signals (Location/Campus/Cost) — NOT a numeric score. The weighted Fit Score algorithm from the PRD was never built. `schools.fit_score` column was dropped on web.
- Academic Fit (deferred — only 2/94 schools have SAT/ACT ranges)
- Distance from Home calculation (haversine from `user_preferences`/`location`)
- DB trigger auto-advances status on interaction

**Recommendation:** Completely rewrite the Schools section. Remove the Fit Score algorithm documentation (it was never implemented). Document the actual pipeline and Personal Fit signals approach. Note Academic Fit as a future enhancement dependent on data availability.

#### 2d. Coaches

**Original PRD:** Basic coach tracking — name, role, email, interaction count, 21-day follow-up suggestion.

**Actual:** Full CRM with:
- Coach insights (response rate analytics, sentiment analysis)
- 13 interaction types with direction and sentiment
- Tags and source tracking
- Colored channels grid
- Analytics gauge
- Follow-up tracking (14-day widget threshold, 30-day analytics threshold)
- Social DM return-confirm flow (iOS divergence from web)
- School-logo avatar

**Recommendation:** Rewrite as "Coach CRM" rather than "Coach Management." This is now a substantial feature module, not a basic contact list.

#### 2e. Communication Engine

**Original PRD:** Communication templates listed as Premium-tier feature (V1.1 future). No mention of NCAA compliance.

**Actual:**
- 33+ coach outreach templates with smart variable resolution
- Optional token segments `[[gate|text]]` (prevents orphan punctuation from empty tokens)
- NCAA compliance guardrails: dead/quiet period enforcement, anti-spam rate limiting
- Contact-window silent swap (switches to allowed channels during restricted periods)
- Send Profile: shareable athlete page with per-coach tracking, QR code, PDF export
- Quick Comm wizard: unified missing-info step, send composers for email/text/social
- Template metric row for primary metric inclusion

**Recommendation:** Add a dedicated "Communication & Compliance" section. This is a major differentiator — no competitor offers NCAA-calendar-aware communication guardrails at this price point. Promote from "future Premium feature" to "core product capability."

#### 2f. NCAA Recruiting Calendar

**Original PRD:** Not mentioned at all.

**Actual:** 22 sport/gender-specific calendar keys derived from official NCAA PDFs. Drives the compliance guardrails, surfaces in the dashboard Recruiting Calendar widget, and feeds the Timeline guidance panels. Gender field + 21-calendar registry + resolver + ruleEngine rewire. Quarterly refresh routine scheduled.

**Recommendation:** Add as a new section. This is a unique, regulation-grounded feature that creates real defensibility.

#### 2g. Recruiting Timeline

**Original PRD:** Basic 4-year timeline with stage detection, guidance copy, 80+ tasks.

**Actual:**
- 4-year phased task system (expanded beyond 80 tasks)
- 5 guidance panels: What Matters Now, Upcoming Milestones, Common Worries, What Not to Stress, Recruiting Calendar
- Collapsible sections with equal-width layout
- 23 real SAT/ACT/FAFSA milestones ported from web
- What-Matters-Now cards that create tasks on tap
- Canonical task sort comparator (identical iOS + web)

**Recommendation:** Update to reflect the 5-panel architecture. The original copy examples (Freshman/Sophomore/Junior/Senior) are still directionally correct and can be preserved.

#### 2h. Performance Metrics

**Original PRD:** Not mentioned.

**Actual:** 66+ metric definitions across 17 sports. Registry-backed, sport-aware. MetricType as String-key struct (iOS) / canonical utils (web). Sport-specific formatting (e.g., .410 batting avg, 82.3 velo, 3.45 ERA). Duration and percent formatters. Trend analysis. Primary metric designation for outreach templates.

**Recommendation:** Add as a new section. This is table-stakes for a sport-agnostic product and should be documented.

#### 2i. Public Profile

**Original PRD:** Not mentioned (PDF export existed as "Recruiting Packet").

**Actual:** Shareable athlete page with:
- Coach-facing actions (Express Interest, Contact Player)
- Per-coach view tracking
- QR code generation
- PDF export
- One-tap share
- Editor + native preview card

**Recommendation:** Replace the "PDF Export" section with "Public Profile & Sharing." The PDF is now one output of a richer sharing system.

#### 2j. Dashboard

**Original PRD:** Static dashboard with suggestions widget, school summary, recent activity.

**Actual:** Customizable widget dashboard with:
- User drag-reorder and on/off per widget
- Events widget (leads on iOS; web leads with Offers — intentional divergence)
- Action Items engine (11 rule-based suggestions, urgency escalation, NCAA-aware suppression)
- Recruiting Calendar widget (merged with Upcoming Milestones)
- Coaches Follow-Up widget (14-day threshold)
- Profile completeness indicator

**Recommendation:** Rewrite dashboard section to reflect widget architecture and customization. The action items engine replaces the "Rule-Based Suggestions" section (which was never built as the full 3-tier architecture described in the PRD — the actual implementation uses a simpler web API approach).

#### 2k. Family System

**Original PRD:** "Multiple Athletes" (1-10), "Secondary Access" (read-only invite).

**Actual:**
- Parent/athlete shared access with role-based permissions
- COPPA compliance
- Multi-athlete switching
- `family_units` + `family_members` tables
- Player family units created directly via Supabase
- Shared canonical player profile (parent sees & edits athlete's data)

**Recommendation:** Expand with actual implementation details. The parent/athlete dynamic is core to the product philosophy and is now implemented, not theoretical.

#### 2l. Notifications

**Original PRD:** Listed as V1.2 future feature.

**Actual:** Shipped:
- Push notifications (APNs) — 3 family-scoped event-driven types (offer/inbound/event)
- In-app notification inbox
- Weekly email digest (planned)
- Note: Was broken from March–August 2026 (3 stacked auth/key bugs); fixed and confirmed on device 2026-08-16.

**Recommendation:** Move from future roadmap to current features. Document the delivery infrastructure.

#### 2m. Accessibility

**Original PRD:** "WCAG 2.1 AA compliance" as design principle.

**Actual:** Substantially implemented:
- WCAG AA compliant
- VoiceOver support with semantic labels
- Dynamic Type support
- 645 literal strings localized (zero-touch), 431 passthrough triaged
- Accessibility-specific test suite
- All interactive elements have `.accessibilityLabel()`
- 44x44pt minimum hit targets

**Recommendation:** Promote from design principle to shipped capability. This is a real differentiator vs. competitors.

---

### 3. COMPETITIVE LANDSCAPE — Needs Update

**Original:** Generic 3-bucket categorization (exposure platforms, recruiting services, content silos). Named competitors: NCSA, BeRecruited, Hudl.

**What's changed:**
- NCSA was acquired by IMG Academy — pricing and positioning may have shifted
- FieldLevel and NextUp are actual competitors (screenshots captured in `/documents/Competiion/`)
- The product now has features (NCAA calendar compliance, 19-sport metrics, communication guardrails) that none of these competitors offer
- The "sport-agnostic" differentiator is now proven, not theoretical

**Recommendation:** Rewrite with:
1. Named competitor analysis including FieldLevel and NextUp
2. Feature comparison matrix using actual shipped features
3. Updated pricing comparisons
4. New differentiators: NCAA compliance engine, sport-agnostic with sport-specific depth, native mobile + web parity, accessibility

---

### 4. BUSINESS MODEL — Still Placeholder

**Original PRD:** Freemium SaaS — Free / Core ($12/mo) / Premium ($25/mo). Revenue projections: Year 1 $10.8K, Year 2 $108K, Year 3 $546K.

**Current state:** No monetization implemented. No Stripe integration. No pricing page. Product is free.

**Recommendation:** This section needs honest reassessment:
1. Acknowledge that monetization has been deferred in favor of product depth
2. Reassess pricing tiers against actual feature set (the "Premium" features like templates and analytics are now part of the core product)
3. Consider whether the original 3-tier model still makes sense or if a simpler model (free trial → single paid tier) is more appropriate given the product's current breadth
4. Update revenue projections with realistic timelines (Year 1 projections assumed paying users within months of launch)
5. Note that the feature set now competes with $1,000+ recruiting services, which may justify higher pricing than $12-25/mo

**Key question for Chris:** Given the product's depth, is the freemium model still the right approach? The product now offers more than NCSA's $3,000 service in several dimensions (NCAA compliance, sport-agnostic coverage, native mobile). A $25-50/month single tier might better reflect value.

---

### 5. GO-TO-MARKET — Needs Grounding in Reality

**Original:** "Content-driven acquisition, word-of-mouth via parents and clubs, pilot groups." Beta Launch docs targeted 5 active beta families by 2026-05-31.

**Current state:** Unknown whether beta was executed. No evidence of active external users in the codebase (though the product is TestFlight-ready on iOS).

**Recommendation:**
1. Document actual beta status — did families outside the household use it?
2. Update GTM with platform-specific channels (App Store for iOS, direct web for Nuxt)
3. The Beta Launch materials (coach script, family outreach texts, dogfooding session, interview guide) are well-structured — assess whether they were used and update for current product
4. The "rule on the wall" from Beta Launch README is still the right discipline: "No new product features until 5 families outside our household have used the app on real recruiting tasks for two consecutive weeks."

---

### 6. ROADMAP — Completely Outdated

**Original:**
- MVP (Weeks 1-13): Auth, CRM, suggestions, timeline, onboarding
- V1.1 (Months 4-5): Email templates, school comparison
- V1.2 (Months 6-7): Push notifications, mobile app
- V1.3 (Months 8-9): Integrations
- V2.0 (Year 2): All sports, coach dashboard

**Actual:** By month 8, the product has shipped:
- Everything in MVP through V1.2
- Most of V1.3 (minus external integrations)
- The headline V2.0 feature (all sports) plus features not on any roadmap (NCAA calendar, performance metrics, public profile, compliance guardrails)

**Recommendation:** Archive the original roadmap as "completed." Write a new roadmap focused on:
1. **Monetization launch** — Stripe, pricing page, tier enforcement
2. **Beta/launch execution** — real users, real feedback
3. **Data quality** — coach contact info, school enrichment completion
4. **External integrations** — Hudl, calendar sync (still unbuilt from V1.3)
5. **Coach-facing tools** — still unbuilt from V2.0, represents B2B opportunity

---

### 7. MARKET RESEARCH — Still Valuable, Needs Updates

**Original:** Comprehensive research validating the core problem. Baseball-heavy examples. December 2025 data.

**What's still valid:**
- Core pain points (organizational chaos, timeline confusion, decision anxiety) — these don't change
- Market sizing (~600K athletes, ~300K target families)
- Willingness to pay evidence
- Success factor analysis
- User persona segments

**What needs updating:**
- Remove baseball-only framing throughout
- Update competitor analysis (FieldLevel, NextUp, NCSA/IMG Academy changes)
- Add multi-sport market data — the TAM expansion from "Baseball (200-300K)" to "All sports (600K+)" has already happened in the product
- Update persona examples to be sport-agnostic
- Note any validation from actual beta users (if available)

---

### 8. USER PERSONAS — Structure Sound, Content Dated

**Original:** 4 segments (Early Explorers 25%, Systematic Planners 30%, Reactive Chasers 25%, Elite Performers 20%). Baseball-only framing. "COMPASS" branding.

**Recommendation:**
- Rename "COMPASS" → "The Recruiting Compass" throughout
- Replace baseball-specific examples with sport-agnostic ones
- Add "Multi-Sport Family" as a potential sub-segment (families with athletes in different sports)
- The segment structure and migration patterns are still sound
- Update feature priorities per segment to reflect actual shipped features

---

### 9. RISK ASSESSMENT — Partially Addressed

**Original risks and current status:**

| Risk | Original Status | Current Status |
|------|----------------|----------------|
| Product-Market Fit | Unvalidated | Product built, but external validation still needed |
| Athlete Privacy / COPPA | Theoretical | COPPA compliance implemented; RLS in place |
| Competitive Response | Theoretical | FieldLevel/NextUp exist but lack NCAA compliance depth |
| Retention | Unknown | Unknown — no external user data |
| Data Quality | Risk | Partially addressed (College Scorecard enrichment), coach data still gap |
| Rules Too Complex | Risk | 11 rules shipped, working on both platforms |
| Technical Debt | Risk | Clean architecture adopted (Schools module), 126+ tests, CI pipeline |

**New risks to add:**
1. **Two-platform maintenance burden** — iOS + web parity requires ongoing effort; divergences exist (Events vs. Offers dashboard lead, social DM flow)
2. **Solo developer risk** — all development by one person with AI assistance; bus factor = 1
3. **No revenue** — 8 months of development with zero revenue; runway question
4. **NCAA regulation changes** — recruiting calendar data must be refreshed (quarterly routine exists but depends on manual PDF parsing)
5. **App Store approval** — iOS app needs Apple review; content policies for minors

---

### 10. TECHNICAL ARCHITECTURE — Not Documented Anywhere

**Gap:** None of the business plan documents describe the actual technical architecture. The PRD mentions "Nuxt + Supabase" but the iOS app, clean architecture patterns, CI/CD, testing strategy, and backend infrastructure are undocumented from a business perspective.

**Recommendation:** Add a "Technical Platform" section covering:
- Dual-platform architecture (SwiftUI + Nuxt sharing Supabase backend)
- Row-Level Security for data isolation
- 9 scheduled cron jobs (list purposes)
- 126+ automated tests (unit, integration, accessibility, E2E)
- CI/CD pipeline (GitHub Actions, TestFlight)
- Clean architecture reference implementation (Schools module)
- WCAG AA accessibility compliance
- PBXFileSystemSynchronizedRootGroup (Xcode 16 auto-inclusion)

This matters for business planning because it demonstrates product maturity and reduces perceived technical risk for investors/partners.

---

## Documents to Archive

These documents should be moved to an `archives/` folder with a note that they represent historical planning, not current product state:

1. **COMPASS PRD** (`Documents/TRC Product Requirements Document.md`) — the baseball-only version; superseded by the TRC PRD
2. **MVP planning files** (`Planning Documents/MVP/`) — MVP is complete and exceeded
3. **Original recruiting timeline iterations** (`Planning Documents/Recruiting Timeline/recruiting plan - chatgpt/perplexity`) — content was incorporated; originals are historical

---

## Recommended New Documents

| Document | Purpose |
|----------|---------|
| **Product Capabilities Overview** | 2-3 page summary of what the product actually does today (for external audiences) |
| **Technical Architecture Brief** | 1-page tech overview for business contexts |
| **Competitive Feature Matrix** | Side-by-side comparison with FieldLevel, NextUp, NCSA |
| **Monetization Strategy v2** | Updated pricing hypothesis based on actual feature set |
| **Launch Readiness Checklist** | What's needed before charging money (Stripe, App Store, ToS, privacy policy) |

---

## Priority Order for Updates

1. **Product Capabilities Overview** (new) — this is the most urgent gap; no document accurately describes the current product
2. **Business Plan executive summary + product section** — update to reflect reality
3. **Competitive Feature Matrix** (new) — needed for positioning decisions
4. **Monetization Strategy v2** (new) — needed before launch
5. **Market Research updates** — lower priority since core findings still hold
6. **Persona updates** — lowest priority; structure is sound

---

## Key Strategic Questions These Documents Should Force

1. **When does monetization launch?** The product has more depth than most $25/mo SaaS tools. Every month without revenue is a month of zero validation on willingness to pay.

2. **Has the beta happened?** The Beta Launch docs from May 2026 set a clear bar: "5 families outside our household using it for two consecutive weeks." If this hasn't happened, it's the most important next step — ahead of any new feature work.

3. **Is the two-platform strategy sustainable?** Maintaining iOS + web parity with a solo developer is expensive. The business plan should address whether both platforms are needed for launch or if one could lead.

4. **What's the actual TAM with 19 sports?** The original docs sized the market at 200-300K baseball families. With 19 sports, the addressable market is potentially 3-5x larger. This changes the business case significantly.

5. **Does the product need a coach-facing side?** The V2.0 roadmap included "Coach dashboard." The Public Profile with Express Interest / Contact Player actions already creates a coach touchpoint. This could be a B2B revenue stream (schools pay for access to interested athletes).
