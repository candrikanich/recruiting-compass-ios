# Web parity — Socials on public profile

**Date:** 2026-08-19
**Origin:** iOS added a tappable Social section to the public profile card. Web must match (no gate — decided with user).

## What iOS shipped (this branch `feat/quick-comm-wizard`)

- `PublicProfileData.SocialSection { twitterHandle, instagramHandle, tiktokHandle, facebookUrl }`, `isEmpty` when all blank.
- `PublicProfileCard` renders a **Social** section (only when non-empty) below Target Schools.
- Each handle → tappable link opening the profile, with an `arrow.up.right` affordance.
- `SocialLinkBuilder` (new, mirrors web `utils/socialMediaHandlers.ts`):
  - twitter → `https://twitter.com/{handle w/o @}`
  - instagram → `https://instagram.com/{handle w/o @}`
  - tiktok → `https://tiktok.com/@{handle w/o @}`
  - facebook → stored full URL, `https://` prefixed if missing scheme
- **No gate**: socials render unconditionally when present (no per-handle or section toggle, no DB change). Matches the other public sections except those have persisted show* flags — socials deliberately don't.

## Web work (repo `recruiting-compass-web`)

Target: `pages/p/[slug].vue` (public shared profile). Currently shows **no** socials.

1. Fetch/pass the athlete's `twitter_handle`, `instagram_handle`, `tiktok_handle`, `facebook_url` into the slug page's profile payload (whatever loader `[slug].vue` uses).
2. Add a **Social** section, visually consistent with the existing sections, shown only when ≥1 handle present.
3. Render each present handle as a link opening the profile in a new tab.
4. Extend `utils/socialMediaHandlers.ts` — it only has `openTwitter`/`openInstagram`. Add `openTikTok` (`https://tiktok.com/@{clean}`) and `openFacebook` (raw url, `https://` prefixed if missing). Keep the existing `@`-strip logic.
5. No DB migration, no visibility toggle.

## Parity checks

- URL formats must match `SocialLinkBuilder` byte-for-byte (twitter.com not x.com; tiktok `@` prefix; instagram.com).
- Section only appears when non-empty on both platforms.
- Handle stored with or without leading `@` — strip before building URL on both.

## Privacy note (flagged, decided: proceed no-gate)

Public share link exposes socials to anyone with the URL. No share-toggle exists for socials (unlike phone/email). If product later wants opt-in, add a `show_social` flag to both platforms + the profile schema.
