# Design System Token Consolidation — iOS

**Date:** 2026-03-10
**Approach:** Option B — Layered (three phases, each buildable independently)
**Goal:** Establish a semantic color vocabulary on iOS that matches the web app exactly, fix critical color mismatches, introduce typed badge colors, add skeleton loading views, and document the system for AI sessions.

---

## Context

The web app completed token consolidation on 2026-03-10:
- Single source of hex values in `@theme` (TailwindCSS)
- `BadgeColor` / `ButtonColor` TypeScript types constrain color usage
- Four `docs/design/` spec files serve as AI session references

The iOS app currently has:
- `AppColors.swift` — raw descriptive names (`primaryGreen`, `accentBlue`) with no semantic role vocabulary
- `BadgeView` — accepts `Color` directly, no type constraint
- `PriorityTier` — A=gold, B=silver, C=bronze (wrong; web is A=red, B=orange, C=slate)
- `LoadingStateView` — spinner only, no skeleton variants
- `AnalyticsChartColors` — raw hex disconnected from AppColors

---

## Phase 1: Foundation

### AppColors.swift — Two-layer structure

**Layer 1: Brand palette** (`Color.brand.*`)

Seven palettes, four steps each (100/500/600/700), matching web Tailwind steps:

| Palette | Role |
|---------|------|
| `blue` | Primary actions, links, in-progress |
| `emerald` | Success, completed, inbound |
| `orange` | Warning, pending, reach |
| `purple` | Secondary, outbound, academic |
| `red` | Error, danger, destructive, negative |
| `slate` | Neutral, disabled, default |
| `indigo` | Accent (reserved for future button use) |

Usage: `Color.brand.blue600`, `Color.brand.emerald100`, etc.

**Layer 2: Semantic aliases** (`Color.semantic.*`)

Role-named shortcuts referencing brand tokens. Existing names (`errorRed`, `accentBlue`, etc.) become typealiases here during migration to avoid breaking callers.

| Alias | Maps to | Use for |
|-------|---------|---------|
| `actionPrimary` | `brand.blue600` | Primary interactive elements |
| `success` | `brand.emerald600` | Success states |
| `warning` | `brand.orange600` | Warning states |
| `danger` | `brand.red600` | Destructive/error states |
| `muted` | `brand.slate500` | Secondary text, disabled |

### BadgeColor enum

File: `TheRecruitingCompass/Shared/Components/BadgeColor.swift`

```swift
enum BadgeColor: CaseIterable {
    case blue, emerald, orange, purple, red, slate
}
```

`BadgeView` updated to accept `BadgeColor` instead of `Color`. Internal mapping:
- Background: `badgeColor.color100.opacity(1)` (light variant)
- Foreground: `badgeColor.color700`

### AppGradients.swift

Updated to reference `Color.brand.*` instead of raw `Color(red:green:blue:)` values.

---

## Phase 2: Call Site Sweep

### Critical mismatches

| Location | Current | Correct |
|----------|---------|---------|
| `PriorityTier.a.badgeColor` | Gold `Color(red:1.0, green:0.84, blue:0)` | `.red` |
| `PriorityTier.b.badgeColor` | Silver `Color(red:0.75…)` | `.orange` |
| `PriorityTier.c.badgeColor` | Bronze `Color(red:0.80…)` | `.slate` |
| `FitScoreBadge` score ≥70 | `.green` (system) | `BadgeColor.emerald` |
| `FitScoreBadge` score ≥50 | `.orange` (system) | `BadgeColor.orange` |
| `FitScoreBadge` score <50 | `.red` (system) | `BadgeColor.red` |
| `AnalyticsChartColors` | Raw hex strings | `Color.brand.*` |

**Note on PriorityTier B:** Web uses raw Tailwind `amber` for tier B. iOS uses `.orange` — the closest semantic match. Amber is not added to the brand palette to avoid fragmenting the vocabulary (same rationale documented in web's `colors.md`).

### Sweep rules

- All `BadgeView(color: .green/.blue/.orange/.red/.gray/.purple)` calls → `BadgeView(color: .emerald/.blue/.orange/.red/.slate/.purple)`
- Raw system colors used as **status indicators** → replace with `Color.brand.*` or `BadgeColor`
- Raw system colors used for **non-semantic UI** (SF Symbol tints, structural layout) → leave as-is

---

## Phase 3: Additions

### Skeleton loading views

File location: `TheRecruitingCompass/Shared/Components/`

**`ShimmerModifier`** — `ViewModifier` applying animated shimmer. Respects `@Environment(\.accessibilityReduceMotion)`: animates normally when false, shows static placeholder when true.

**`ListRowSkeleton`** — shimmer row for list loading states. Used in Schools, Coaches, Interactions lists as `ForEach(0..<5) { _ in ListRowSkeleton() }`.

**`CardSkeleton`** — shimmer card for grid/card loading states. Used in Dashboard stat cards, school cards.

`LoadingStateView` retained for full-screen initial loads where content shape is unknown.

### Design docs

Four files in `docs/design/`:

| File | Contents |
|------|----------|
| `tokens.md` | Brand palette hex values, semantic aliases, SwiftUI usage patterns |
| `colors.md` | Role definitions (blue=action, emerald=success, etc.) with SwiftUI-specific notes, quick reference table |
| `states.md` | Domain state → `BadgeColor` mapping: PriorityTier, FitScore tier, interaction sentiment/direction |
| `components.md` | `BadgeView`, skeleton components, `LoadingStateView` usage guide |

---

## File Changes Summary

| Phase | Files Modified | Files Created |
|-------|---------------|---------------|
| 1 | `AppColors.swift`, `AppGradients.swift`, `BadgeView.swift` | `BadgeColor.swift` |
| 2 | `PriorityTier.swift`, `FitScoreBadge.swift`, `AnalyticsChartColors.swift`, all views using raw colors | — |
| 3 | — | `ShimmerModifier.swift`, `ListRowSkeleton.swift`, `CardSkeleton.swift`, `docs/design/*.md` |

---

## Verification per Phase

Each phase must pass before starting the next:
```bash
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'
```
