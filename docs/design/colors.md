# Color Roles — iOS

Source: `BadgeColor.swift`. Use `BadgeColor` for all domain status badges.

## Vocabulary

```swift
enum BadgeColor { case blue, emerald, orange, purple, red, slate }
```

## Blue — Action / In-Progress / Interaction Type

**Signal:** Active, interactive, primary call to action, in-progress.

**Use for:**
- Primary buttons, CTA links
- `InteractionType.badgeColor` (all types always blue)
- In-progress school status (`contacted`)
- Active filter states

**Brand tokens:** `Color.Brand.blue100/.blue500/.blue600/.blue700`

---

## Emerald — Success / Positive / Inbound / Complete

**Signal:** Done, good outcome, received communication, strong fit.

**Use for:**
- `Sentiment.veryPositive`
- `Direction.inbound`
- `SchoolStatus.recruited`, `.offerReceived`, `.committed`
- `FitTier.match`, `.safety`
- Fit score ≥ 70
- `InterestLevel.high`

**Brand tokens:** `Color.Brand.emerald100/.emerald500/.emerald600/.emerald700`

---

## Orange — Warning / Pending / Reach

**Signal:** Needs attention, not yet resolved, below target but achievable.

**Use for:**
- `SchoolStatus.officialVisitInvited`, `.officialVisitScheduled`
- `FitTier.reach`
- Fit score ≥ 50 and < 70
- `PriorityTier.b` (Strong Interest)
- `InterestLevel.medium`

**Brand tokens:** `Color.Brand.orange100/.orange500/.orange600/.orange700`

---

## Purple — Secondary / Outbound / Academic

**Signal:** Athlete-initiated communication, secondary emphasis.

**Use for:**
- `Direction.outbound`
- `SchoolStatus.campInvite`
- `Division.naia`

**Brand tokens:** `Color.Brand.purple100/.purple500/.purple600/.purple700`

---

## Red — Error / Danger / Destructive / Negative

**Signal:** Bad outcome, delete/remove action, negative sentiment.

**Use for:**
- Destructive action buttons ("Delete")
- `Sentiment.negative`
- `FitTier.unlikely`
- Fit score < 50
- `SchoolStatus.notPursuing`
- `PriorityTier.a` (Top Choice — red signals urgency, not danger; label clarifies)

**Brand tokens:** `Color.Brand.red100/.red500/.red600/.red700`

---

## Slate — Neutral / Unknown / Disabled / Default

**Signal:** No state, not started, unknown, fallback.

**Use for:**
- `SchoolStatus.interested`, `.unknown`
- `Sentiment.neutral`
- `Division.juco`
- `PriorityTier.c` (Fallback)
- `InterestLevel.low`, `.notSet`
- Size badge (always slate)
- Disabled / inactive UI elements

**Brand tokens:** `Color.Brand.slate100/.slate500/.slate600/.slate700`

---

## Quick Reference

| Color | BadgeColor case | Primary iOS domain use |
|-------|----------------|----------------------|
| Blue | `.blue` | Actions, in-progress, interaction type |
| Emerald | `.emerald` | Success, completed, inbound, high interest |
| Orange | `.orange` | Warning, pending, reach, medium interest |
| Purple | `.purple` | Outbound, camp invite |
| Red | `.red` | Error, danger, negative, top priority |
| Slate | `.slate` | Neutral, disabled, fallback |
