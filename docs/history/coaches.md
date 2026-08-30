# Coaches History

## 2026-08-20 — Quick Comm Unified Missing-Info + Questionnaire/Metric Parity
Spec for unified "Complete your info" wizard step before Preview (replacing 4 UI idioms), plus iOS parity for MetricType.defaultUnit alignment (batting_avg/era="" strikeouts="count") and native send-time questionnaire prompt.

## 2026-08-15 — Coach Tile/Detail Consolidation + Send Confirmation
iOS delta spec to unify CoachCardView + CompactCoachCard into one variant-driven tile with canonical 5-icon action row. Also: log interaction only on confirmed MFMailComposeViewController .sent result (not optimistic), with MailComposeView + MessageComposeView UIViewControllerRepresentable wrappers.

## 2026-08-14 — Quick Comm Phase 2b + Phase 3 Plans
Phase 2b: variables panel, amber unresolved highlight, editable subject/body, 160-char text limit. Phase 3: contact-window pre/open swap, anti-spam guardrails (hard block + confirm), Instagram button. Completes web parity for coach outreach.

## 2026-08-13 — iOS Quick Comm Template Parity Spec
Full iOS Quick Comm template parity spec: fix TemplateType decode (email/message/social), port web resolver (77 vars), 3-phase plan for achieving full feature parity.

## 2026-08-14 — iOS Quick Communication template parity (Phases 1 + 2a)
Fixed TemplateType decode (email/message/social) and aligned the model/fetch with the shared DB so all 34 predefined templates appear, then ported web's pure templateResolver 1:1 (registry-driven value builder + COMPUTED formatters), gathered athlete context, and blocked send on unresolved tokens.

## 2026-08-11 — Coaches Needing Follow-up widget
Web-parity dashboard widget: 14-day staleness logic, Email/Text/View Profile actions, visibility toggle.
