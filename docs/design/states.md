# Domain State → Visual Treatment — iOS

Canonical reference for how each domain state maps to `BadgeColor`.

---

## Fit Score — Tier

Source: `FitScore.swift (FitTier.badgeColor)`.

| Tier | BadgeColor | Meaning |
|------|-----------|---------|
| `match` | `.emerald` | Profile aligns well |
| `safety` | `.emerald` | Strong chance of acceptance |
| `reach` | `.orange` | Possible fit, needs development |
| `unlikely` | `.red` | Not a strong fit currently |

---

## Fit Score — Numeric

Source: `FitScoreSection.fitScoreColor()`.

| Score range | Token | Color |
|------------|-------|-------|
| ≥ 70 | `Color.Brand.emerald600` | Good |
| ≥ 50 and < 70 | `Color.Brand.orange600` | Caution |
| < 50 | `Color.Brand.red600` | Poor |

---

## Fit Score — Breakdown Dimensions

Source: `FitScoreSection.swift`.

| Dimension | Token |
|-----------|-------|
| Athletic Fit | `Color.Brand.blue500` |
| Academic Fit | `Color.Brand.purple500` |
| Opportunity Fit | `Color.Brand.emerald500` |
| Personal Fit | `Color.Brand.orange500` |

---

## School — Priority Tier

Source: `PriorityTier.badgeColor`.

| Tier | BadgeColor | Meaning |
|------|-----------|---------|
| `.a` | `.red` | Top choice — urgency to act |
| `.b` | `.orange` | Strong interest |
| `.c` | `.slate` | Fallback / monitoring |

---

## School — Status

Source: `SchoolStatus.badgeColor`.

| Status | BadgeColor |
|--------|-----------|
| `.interested` | `.slate` |
| `.contacted` | `.blue` |
| `.campInvite` | `.purple` |
| `.recruited` | `.emerald` |
| `.officialVisitInvited` | `.orange` |
| `.officialVisitScheduled` | `.orange` |
| `.offerReceived` | `.emerald` |
| `.committed` | `.emerald` |
| `.notPursuing` | `.red` |
| `.unknown` | `.slate` |

---

## School — Division

Source: `Division.badgeColor`.

| Division | BadgeColor |
|----------|-----------|
| `.d1` | `.blue` |
| `.d2` | `.emerald` |
| `.d3` | `.orange` |
| `.naia` | `.purple` |
| `.juco` | `.slate` |

---

## Interaction — Direction

Source: `Direction.badgeColor`.

| Direction | BadgeColor |
|-----------|-----------|
| `.inbound` | `.emerald` |
| `.outbound` | `.purple` |

---

## Interaction — Sentiment

Source: `Sentiment.badgeColor`.

| Sentiment | BadgeColor |
|-----------|-----------|
| `.veryPositive` | `.emerald` |
| `.positive` | `.blue` |
| `.neutral` | `.slate` |
| `.negative` | `.red` |

---

## Interaction — Interest Level

Source: `InterestLevel.badgeColor`.

| Level | BadgeColor |
|-------|-----------|
| `.high` | `.emerald` |
| `.medium` | `.orange` |
| `.low` | `.slate` |
| `.notSet` | `.slate` |
