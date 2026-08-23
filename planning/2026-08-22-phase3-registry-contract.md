# Phase 3 Registry Contract (BYTE-IDENTICAL both platforms)

The two new registries below are the shared data contract. **Every key string, option token,
position-gate value, and urlTemplate MUST be identical on iOS and web.** Only display labels
(`label`/`optionLabels`) are presentation and may be localized, but keep them identical for v1.

Storage: flat JSONB `user_preferences.data` (category `player`). Keys below are the flat keys.
ZERO DB migration. Values validated in Zod (web) + picker option set (iOS). Empty string = unset.

## Registry A — Athlete Attributes

Shape: `AttributeDef { key, label, options[], optionLabels{}, positions?[] }`.
`positions` (optional): attribute renders only when the athlete's primaryPosition is in this list
(position values are the canonical position LABELS from CanonicalPositions / SPORT_POSITIONS).
No `positions` = show for all athletes of that sport.

Files: iOS `Core/Utilities/AthleteAttributes.swift` (`static let bySport: [String:[AttributeDef]]`,
helper `attributes(for sport: String?) -> [AttributeDef]` returning `[]` for nil/unknown — mirror
CanonicalPositions). web `utils/attributes/canonical.ts` (`ATTRIBUTES_BY_SPORT: Record<string, AttributeDef[]>`,
`attributesForSport(sport?)`).

| Sport | key | label | options → optionLabels | positions gate |
|---|---|---|---|---|
| Baseball | `bats` | Bats | L→Left, R→Right, S→Switch | — |
| Baseball | `throws` | Throws | L→Left, R→Right | — |
| Softball | `bats` | Bats | L→Left, R→Right, S→Switch | — |
| Softball | `throws` | Throws | L→Left, R→Right | — |
| Basketball | `shooting_hand` | Shooting Hand | L→Left, R→Right | — |
| Soccer | `dominant_foot` | Dominant Foot | L→Left, R→Right, Both→Both | — |
| Volleyball | `hitting_hand` | Hitting Arm | L→Left, R→Right | — |
| Tennis | `racket_hand` | Plays | L→Left-handed, R→Right-handed | — |
| Tennis | `backhand_style` | Backhand | one→One-handed, two→Two-handed | — |
| Golf | `golf_handedness` | Plays | L→Left-handed, R→Right-handed | — |
| Lacrosse | `dominant_hand` | Dominant Hand | L→Left, R→Right | — |
| Ice Hockey | `shoots` | Shoots | L→Left, R→Right | — |
| Ice Hockey | `catches` | Catches (Goalie) | L→Left, R→Right | `["Goalie"]` |
| Water Polo | `wp_dominant_hand` | Dominant Hand | L→Left, R→Right | — |
| Rowing | `rowing_side` | Rigging Side | port→Port, starboard→Starboard, both→Both, cox→Coxswain | — |
| Rowing | `rowing_discipline` | Discipline | sweep→Sweep, scull→Sculling, both→Both | — |
| Football | `throwing_hand` | Throwing Hand | L→Left, R→Right | `["Quarterback"]` |
| Football | `kicking_foot` | Kicking Foot | L→Left, R→Right | `["Kicker","Punter"]` |

**No attributes** (do NOT add): Track & Field, Cross Country, Swimming, Wrestling, Field Hockey.

Position-gate values verified against the position registry: Ice Hockey has "Goalie"; Football has
"Quarterback","Kicker","Punter". Match those exact label strings.

## Registry B — Recruiting Services (v1)

Shape: `ServiceDef { key, label, valueKind: 'id'|'url', urlTemplate?, signupUrl, placeholder, sports[] }`.
Render: input bound to `data[key]`; label + "Get your profile" link → `signupUrl`. Public card / server
output: if `urlTemplate` present and value set → link `urlTemplate.replace('{value}', value)`; if
`valueKind==='url'` → link is the stored value itself; else plain text.

Files: iOS `Core/Utilities/RecruitingServices.swift` (`servicesForSport(_:) -> [ServiceDef]`),
web `utils/services/canonical.ts` (`servicesForSport(sport?)`). Keep existing keys `perfect_game_id`
/ `prep_baseball_id` VERBATIM (already in the model — no data migration).

| key | label | valueKind | urlTemplate | signupUrl | placeholder | sports |
|---|---|---|---|---|---|---|
| `ncsa_id` | NCSA | id | (none) | https://www.ncsasports.org/ | ID Number | ALL 17 |
| `hudl_url` | Hudl | url | (none — link is the value) | https://www.hudl.com/ | Profile URL | Football, Basketball, Volleyball, Soccer, Lacrosse, Ice Hockey, Field Hockey, Water Polo, Wrestling |
| `perfect_game_id` | Perfect Game | id | `https://www.perfectgame.org/Players/Playerprofile.aspx?ID={value}` | https://www.perfectgame.org/ | ID Number | Baseball, Softball |
| `prep_baseball_id` | Prep Baseball Report | id | (none — signup-only) | https://www.prepbaseballreport.com/ | ID Number | Baseball, Softball |

### PBR link addendum (2026-08-22 — restore-on-both decision)
`ServiceDef` gains `linkKind: 'template' | 'url' | 'prepBaseball'` (default `template`):
- `template` — link = `urlTemplate.replace('{value}', value)` (Perfect Game).
- `url` — link = the stored value itself (Hudl).
- `prepBaseball` — link built from the athlete's `prep_baseball_state` + the athlete's **name** (NOT `prep_baseball_id`), via the canonical algorithm below. `prep_baseball_id` becomes `linkKind: prepBaseball`, `urlTemplate` omitted.

`serviceProfileUrl(def, { value, state, name })` switches on `linkKind`. Both platforms MUST produce byte-identical URLs. Canonical algorithm (web `utils/recruitingLinks.ts` is the reference; iOS ports it to a `RecruitingLinks` util verbatim):
```
BASE = "https://www.prepbaseballreport.com/profiles"
buildPrepBaseballUrl(state, name):
  code = normalizeStateCode(state)   // trim; UPPER if in STATE_CODES set; else STATE_NAME_TO_CODE[lower]; else null
  if !code: return null
  slug = slugifyPlayerName(name):    // lower; drop ['".]; [^a-z0-9]+ -> '-'; trim leading/trailing '-'
  if !slug: return null
  return `${BASE}/${code}/${slug}`   // e.g. .../profiles/OH/owen-andrikanich
```
iOS mirrors the SAME `STATE_CODES` + `STATE_NAME_TO_CODE` table and the SAME slugify regex. Editor: PBR row keeps a `prep_baseball_state` input (US-state picker) as today on web; the profile link renders when state + name resolve. Keep `prep_baseball_state` surfaced.

### Services v2 (2026-08-23 — verified, buildable; BYTE-IDENTICAL both platforms)
All new keys are flat JSONB → ZERO migration. Renderers already registry-driven → pick up automatically.
Rule: clean stable numeric id whose bare-id URL resolves → `valueKind:'id'`, `linkKind:'template'`, `{value}`.
Name/compound-slug where bare id fails → `valueKind:'url'`, `linkKind:'url'` (store full URL, like Hudl).

| key | label | valueKind | urlTemplate ({value}) | signupUrl | sports |
|---|---|---|---|---|---|
| `athletic_net_id` | Athletic.net | id | `https://www.athletic.net/athlete/{value}` | athletic.net | Track & Field, Cross Country |
| `milesplit_url` | MileSplit | url | (value is URL) | milesplit.com | Track & Field, Cross Country |
| `swimcloud_id` | SwimCloud | id | `https://www.swimcloud.com/swimmer/{value}/` | swimcloud.com | Swimming |
| `utr_id` | Universal Tennis (UTR) | id | `https://app.utrsports.net/profiles/{value}` | utrsports.net | Tennis |
| `tennis_recruiting_id` | Tennis Recruiting Network | id | `https://www.tennisrecruiting.net/player.asp?id={value}` | tennisrecruiting.net | Tennis |
| `elite_prospects_id` | Elite Prospects | id | `https://www.eliteprospects.com/player/{value}` | eliteprospects.com | Ice Hockey |
| `sportsrecruits_id` | SportsRecruits | id | `https://sportsrecruits.com/athlete/{value}` | sportsrecruits.com | Soccer, Lacrosse, Volleyball, Field Hockey |
| `concept2_id` | Concept2 Logbook | id | `https://log.concept2.com/profile/{value}` | log.concept2.com | Rowing |
| `on3_url` | On3 | url | (value is URL) | on3.com | Football, Basketball |
| `sports247_url` | 247Sports | url | (value is URL) | 247sports.com | Football, Basketball |

Placeholders: id-kind → "ID Number"; url-kind → "Profile URL". Order after the v1 four.
signupUrl values above are abbreviated to the bare domain — store the FULL https form (like v1),
byte-identical both platforms: `https://www.athletic.net/`, `https://www.milesplit.com/`,
`https://www.swimcloud.com/`, `https://www.utrsports.net/`, `https://www.tennisrecruiting.net/`,
`https://www.eliteprospects.com/`, `https://sportsrecruits.com/`, `https://log.concept2.com/`,
`https://www.on3.com/`, `https://247sports.com/`.
Also: the public-profile data projection (web `server/api/public/profile/[slug].get.ts` +
`ProfilePreview.vue` + `PublicProfileData.athletic` type; iOS `PublicProfileData`/`PublicProfileViewModel`)
must carry the 10 v2 keys or they show in the editor but not on the public card.
DEFERRED still (no verifiable public URL): TopDrawerSoccer, Junior Golf Scoreboard, TrackWrestling,
FloWrestling. Do NOT add guessed templates.
Caveat (UI copy, not template): Athletic.net/Elite Prospects rely on bare-id→slug redirect — flag a
one-time device check; Concept2/TennisRecruiting profiles may be privacy/login gated (link still valid).

Older DEFERRED note (superseded by the v2 table above for the verified ones):

## UI wiring (both platforms)
- iOS `Features/Preferences/Views/Tabs/AthleticsTab.swift`, web `components/Settings/PlayerDetailsAthleticsTab.vue`:
  Replace the hardcoded bats/throws card + the `isBaseballOrSoftball`-gated PG/PBR block with
  registry-driven rendering: iterate `attributesForSport(primarySport)` (apply position gate against
  the athlete's primaryPosition) and `servicesForSport(primarySport)`. bats/throws now appear for
  baseball/softball ONLY because the registry lists them there — so the `isBaseballOrSoftball`
  special-case can be dropped in favor of registry membership.
- Public profile + `server/agent-content/profile.ts` (web) / iOS public card: emit service IDs from
  the services registry (gated by the athlete's sport), NOT a hardcoded `prep_baseball_id`.
- Profile display + edit-history label maps (web `useProfile.ts`/`useProfileEditHistory.ts`, iOS
  equivalents): source attribute/service labels from the registries.

## Parity checklist (must match byte-for-byte)
key strings · option tokens (L/R/S, Both, one/two, port/starboard/both/cox, sweep/scull/both) ·
positions-gate label strings · urlTemplate strings · which sports gate which attribute/service.
