# Handoff — Implement Coach Outreach "Log on Confirmed Send" (iOS)

**Run this in a fresh Claude session inside `recruiting-compass-ios`.**
Copy the prompt block below and paste it as your first message.

Origin: ports web change `1df52a39`. iOS diverges intentionally — logs only on a confirmed `.sent` from an in-app composer (no optimistic log, no undo). Full rationale + task list in [`planning/iOS_SPEC_CoachOutreach_SendConfirmation.md`](./iOS_SPEC_CoachOutreach_SendConfirmation.md).

---

## Paste-me prompt

```
Implement the spec at planning/iOS_SPEC_CoachOutreach_SendConfirmation.md.

Feature: when an athlete sends an email/text to a coach from the Quick Communication
sheet, log an outbound interaction — but ONLY when the send is actually confirmed.
Use MFMailComposeViewController / MFMessageComposeViewController (in-app composers that
report .sent), NOT the current mailto:/sms: openURL hand-off. No optimistic log, no undo.

Before writing code:
1. Read the full spec end to end.
2. Orient (60s): open QuickCommunicationView.swift (:207-235 send buttons),
   QuickCommunicationViewModel.swift (mailtoURL/smsURL, filledBody),
   InteractionsManaging.swift + InteractionsServiceImpl.swift (createInteraction),
   InteractionCreateRequest.swift, AddInteractionViewModel.swift:216-274
   (how a VM resolves loggedBy + familyUnitId — mirror it).
3. Resolve the two spec unknowns FIRST and report findings before task 5:
   - Does a DB trigger already set coaches.last_contact_date on interactions insert?
     (Check supabase migrations / server behavior.) If yes, SKIP spec task 5.
   - Confirm InteractionType raw values are exactly "email" and "text".

Then implement tasks 1-6 in order. Use TDD: write the ViewModel logging tests (task 6)
RED first — .sent logs once, .cancelled/.saved/.failed and the canSendMail()==false
fallback log NOTHING — then implement to green. Mock InteractionsManaging.

Guardrails:
- Only touch files named in the spec + their tests. No scope creep.
- The fallback path (no Mail/Messages account) must log nothing — do not reintroduce
  the false-positive the whole change exists to remove.
- Success toast copy: "Logged email to Coach {fullName}." / "Logged text to Coach {fullName}."

Build gate before you call it done:
- xcodebuild build clean (no new warnings/errors in touched files)
- new unit tests green
- run it: launch in simulator, open a coach, tap Send Email, confirm the composer
  presents; on Simulator (no Mail account) confirm the fallback opens the mail URL and
  logs nothing; describe what you'd expect on a real device (.sent → one logged
  interaction visible in Interactions).

Report: files changed, test results, build status, and the two unknowns' answers.
Commit only when I say so.
```

---

## Acceptance checklist (verify before merge)

- [ ] Two unknowns resolved & reported (last_contact_date trigger; InteractionType raws)
- [ ] `MailComposeView` + `MessageComposeView` wrappers added
- [ ] `QuickCommunicationViewModel.logSend(_:)` logs on confirmed send only
- [ ] Send buttons present in-app composer; `canSendMail()`/`canSendText()` fallback logs nothing
- [ ] `last_contact_date` handled (trigger → skip; else `CoachUpdateRequest.lastContactDate` added)
- [ ] Tests: `.sent` logs once; other results + fallback log nothing
- [ ] `xcodebuild build` clean; unit tests green; ran in simulator
- [ ] Scope limited to spec files
