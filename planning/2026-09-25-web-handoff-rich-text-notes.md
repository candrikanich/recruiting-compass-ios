# Web Handoff — Rich-Text Notes (iOS + web in parallel)

**Date:** 2026-09-25 · **Status:** DRAFT · **From:** iOS · **To:** web repo (`recruiting-compass-web`)
**Parent plan:** `planning/2026-09-25-ios26-modernization-plan.md` (Phase 5)
**Goal:** basic formatting (bold / italic / bullet / numbered list) in long-form notes, shipped on
**both platforms in the same release** so neither shows raw markup.

## Honest priority
Nice-to-have, not table stakes. Plain-text notes are the norm in recruiting CRMs; formatting helps for
long coach-call notes and lists ("questions to ask"). Web editors commonly have it; mobile notes fields
much less so. Worth doing cheaply; don't let it delay launch (#82). Ship only if the cost stays low.

## Contract (shared by both platforms — do not diverge)

**Storage:** a **Markdown subset stored in the existing text columns**. No schema migration. Existing
plain-text notes are already valid (they just contain no markup).

**Allowed grammar (exactly this, nothing else):**

| Feature | Markdown |
|---|---|
| Bold | `**text**` |
| Italic | `*text*` |
| Bullet list | `- item` |
| Numbered list | `1. item` |
| Paragraph / line break | blank line / single newline preserved |

**Not allowed / must be neutralized on render:** raw HTML, headings, links, images, code, tables,
blockquotes. Unknown syntax renders as literal text. This is the XSS + parity boundary.

**Shared test fixtures:** put ~15 input→expected-plain-text/render cases in one JSON file in the web
repo (`tests/fixtures/rich-notes.json`); iOS mirrors it in a unit test. Include: plain text unchanged,
nested bold+italic, list with bold item, `<script>` / `<img onerror>` literal text, unbalanced `**`,
Windows/Unix newlines, emoji, 10k-char note.

**Plain-text projection** (`stripMarkup(md) -> String`) — needed wherever notes are shown as a single
line or exported: list-row previews, search snippets, CSV export (web + iOS), PDF/reports, any email/SMS
that quotes a note. Same rules both platforms.

## Scope: which fields

**In (v1) — private free-text notes:**
- School notes (`SchoolNotesCard.vue` ↔ iOS `SchoolNotesSection`, `SchoolFormView`)
- Coach notes (`EditCoachModal.vue` ↔ iOS `NotesSection`, `CoachFormView`)
- Interaction notes/content (`InteractionAddForm.vue` ↔ iOS `AddInteractionView`)
- Offer notes (`pages/offers/[id].vue` ↔ iOS `AddOfferForm`)
- Coaching philosophy (`CoachingPhilosophy.vue` ↔ iOS `SchoolCoachingPhilosophySheet`) — optional

**Out (explicitly):**
- **Communication templates + message composers** (`TemplateEditor.vue`, `MessageComposer.vue`,
  iOS `TemplateEditorView`, `QuickCommunicationView`) — output goes to SMS/email; formatting would leak
  as literal `**`. Stay plain text.
- **Public profile bio / lookingFor** (`ProfileContentEditor.vue`, iOS `PublicTab`) — public-facing,
  larger XSS + moderation surface. Revisit separately.
- Feedback, save-search, metric, event forms — short fields.

## Web work (this repo's handoff)

Current state (audited read-only 2026-09-25): notes are plain `<textarea>`/`FormTextarea.vue`. No markdown
or editor library. `dompurify@^3.4` and `sanitize-html@^2.17` are **already dependencies**.

1. **Decision needed — editor (see Q1):** minimal toolbar-over-textarea vs. Tiptap.
2. **Renderer:** one composable/component, e.g. `components/DesignSystem/RichNoteView.vue` +
   `utils/richNotes.ts`: markdown-subset → HTML → **DOMPurify with a strict allowlist**
   (`strong, em, ul, ol, li, p, br`; no attributes). Never `v-html` raw note text. Server-side render is
   not needed if you sanitize on the client at display time.
3. **Editor component:** `RichNoteEditor.vue` (v-model = markdown string). Toolbar: B, I, bullet, number.
   Must be keyboard-operable with labelled buttons (WCAG AA, matches iOS a11y bar).
4. **Server validation (Zod):** notes fields already length-capped? confirm; add a max length (suggest
   10k chars) if missing. Server does **not** need to parse markdown, but must not trust it —
   sanitization stays at render. Optionally strip disallowed constructs on write.
5. **`stripMarkup` util** + wire into list previews, search snippets, CSV export (see iOS CSV export
   work in #161), any place notes are truncated.
6. **Rollout:** behind the same release as iOS. No feature flag needed pre-launch (no users). If a flag
   is used, iOS must respect it — iOS has no flag system today, so prefer no flag.
7. **Tests (TDD):** renderer fixtures incl. XSS vectors; `stripMarkup`; editor v-model round-trip;
   a11y (toolbar labels, focus); existing-plain-text-note unchanged.

## iOS work (for reference — tracked in the iOS plan, Phase 5)

- Rich `TextEditor(text: Binding<AttributedString>)` is **iOS 26+** (docs: "Building rich SwiftUI text
  experiences"). On lower OS, fall back to plain `TextEditor` on the markdown source.
- **Risk — serialization:** `AttributedString(markdown:)` parses; there is **no built-in markdown
  serializer**. Need a small `AttributedString → markdown-subset` writer over `inlinePresentationIntent`
  and `presentationIntent` (list/paragraph). Unit-test against the shared fixtures. Budget for this.
- Read-only views (`Text(AttributedString(markdown:))`) work on iOS 18+ and render the same subset, so
  display parity is available regardless of the deployment-target decision.
- Constrain the editor's formatting to bold/italic/lists via the formatting-definition API.

## Coordination

- Land the **contract + fixtures + `stripMarkup`** first (both repos), then editor/renderer in parallel.
- Old iOS builds would show raw `**` — moot pre-launch (no users). If shipped post-launch, renderer-first
  release is required.
- Update `platform-parity` ledger when both sides merge.

## Open questions (web)

1. Editor: **(a)** toolbar-over-textarea inserting markdown + preview (no new dep, less WYSIWYG) vs.
   **(b)** Tiptap restricted to the 4 features (best UX, new dependency + markdown extension).
   Recommendation: **(b)** if we really want this, since fake WYSIWYG on textarea is fiddly; else skip.
   New dependency needs Chris's OK.
2. Are notes currently length-capped in Zod / DB? (Web repo owner to confirm.)
3. Do notes appear in emails/reports/exports beyond the list above? (grep `notes` in `server/`.)
