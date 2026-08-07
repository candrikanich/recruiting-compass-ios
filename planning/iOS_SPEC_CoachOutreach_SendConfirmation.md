# iOS Spec — Coach Outreach: Log on Confirmed Send

**Source of truth:** web change `1df52a39` (feat: optimistic send-log with one-tap undo).
**iOS divergence (approved):** iOS uses an **in-app mail/message composer** (`MFMailComposeViewController` / `MFMessageComposeViewController`) that reports a real send result. So iOS does **not** copy the web's optimistic-log-then-undo. It logs the interaction **only when the composer returns `.sent`**. No undo, no toast action button, no false "sent" for composed-but-abandoned drafts.

## Why iOS differs from web

| | Web | iOS (this spec) |
|---|---|---|
| Hand-off | `mailto:`/`sms:` → external app, no callback | `MFMailComposeViewController` in-app, delegate reports `.sent`/`.cancelled`/`.saved`/`.failed` |
| When logged | Optimistically on tap | Only on `.sent` |
| Correction | Undo toast (8s) deletes the row | Not needed — never logs an unsent message |
| `last_contact_date` | App writes it, undo restores prior | App writes it on confirmed send (no undo to restore) |

Net: iOS gets a **strictly better** UX for free because the platform exposes the outcome web can't see.

## Current iOS state (verified)

- `QuickCommunicationView.swift:207-235` — "Send Email"/"Send Text" buttons call `onOpenURL(mailto/sms)` then `onDismiss()`. **No logging today.** Uses `mailto:`/`sms:` via `@Environment(\.openURL)` — MessageUI is **not** used anywhere in the app.
- `QuickCommunicationViewModel.swift:88/100` — `mailtoURL()` / `smsURL()` builders; `filledBody` (template-substituted); `coach`, `schoolName` only. **No** `interactionsService`, user id, or family id injected.
- `InteractionsManaging.swift:17` — `createInteraction(_ InteractionCreateRequest) async throws -> Interaction`; `:22` `deleteInteraction`. Impl `InteractionsServiceImpl.swift:132-148`.
- `InteractionCreateRequest.swift` — fields: `schoolId?`, `coachId?`, `eventId?`, `type` (`InteractionType`), `direction` (`Direction`), `occurredAt: Date`, `subject?`, `content?`, `sentiment?`, `loggedBy`, `familyUnitId`. Already sanitizes subject/content.
- `Toast.swift` / `ToastModifier.swift` — success/error/info/warning, auto-dismiss, **X-dismiss only, no action button**. Reused as-is (no extension needed).
- `CoachUpdateRequest.swift` — has `nextContactDate`, **NO `lastContactDate`**. See task 5.
- Reference for how a VM gets `loggedBy` + `familyUnitId`: `AddInteractionViewModel.swift:216-274` (`submitInteraction()` → `createInteraction`, then cache invalidation `:271-274`). **Mirror its context-resolution.**

## Implementation tasks

### 1. `MailComposeView` — new file
`.../Features/Coaches/Components/MailComposeView.swift`

`UIViewControllerRepresentable` wrapping `MFMailComposeViewController`.
- Inputs: `recipients: [String]`, `subject: String?`, `body: String?`.
- Output: `onResult: (MFMailComposeResult, Error?) -> Void`.
- Coordinator conforms to `MFMailComposeViewControllerDelegate`; on `didFinishWith` → dismiss the controller, then call `onResult`.
- **Guard:** caller must check `MFMailComposeViewController.canSendMail()` before presenting (no Mail account → composer can't send). See task 4 fallback.

### 2. `MessageComposeView` — new file
`.../Features/Coaches/Components/MessageComposeView.swift`

Same pattern wrapping `MFMessageComposeViewController` (`MessageComposeResult`, `MFMessageComposeViewControllerDelegate`). Inputs `recipients: [String]`, `body: String?`. Guard with `MFMessageComposeViewController.canSendText()`.

### 3. ViewModel — log on confirmed send
`QuickCommunicationViewModel.swift`

- Inject `interactionsService: any InteractionsManaging` (default `InteractionsServiceImpl()`), plus current-user id + `familyUnitId` resolution mirroring `AddInteractionViewModel`. Add `coachId` / `schoolId` from `coach`.
- Add:
  ```swift
  enum SendChannel { case email, text }

  func logSend(_ channel: SendChannel) async {
    do {
      let req = InteractionCreateRequest(
        schoolId: coach.schoolId,
        coachId: coach.id,
        type: channel == .email ? .email : .text,   // verify InteractionType has .email/.text → raw "email"/"text"
        direction: .outbound,
        occurredAt: Date(),
        subject: selectedTemplate?.name,             // QuickComm has no subject field; template name or nil
        content: filledBody.isEmpty ? nil : filledBody,
        sentiment: nil,
        loggedBy: <currentUserId>,
        familyUnitId: <familyUnitId>
      )
      _ = try await interactionsService.createInteraction(req)
      await updateLastContactDate()                  // task 5
      didLogSend = true                              // drive success toast on parent
    } catch {
      logger.error("Failed to log sent interaction: \(error.localizedDescription)")
      errorMessage = "Message sent, but logging it failed."
    }
  }
  ```
- Do **not** log on `.cancelled` / `.saved` / `.failed`.

### 4. Wire the composer into the send buttons
`QuickCommunicationView.swift` (`QuickCommActionsSection`)

Replace the `onOpenURL(mailto); onDismiss()` bodies:
- **Email tap:** if `MFMailComposeViewController.canSendMail()` → present `MailComposeView` (recipients `[coach.email]`, subject = `selectedTemplate?.name`, body = `filledBody`). On result `.sent` → `await viewModel.logSend(.email)` then dismiss + success toast. Any other result → dismiss, no log.
- **Fallback** (`canSendMail() == false`, e.g. Simulator / no Mail account): keep the existing `openURL(mailtoURL())` behavior and **do not log** (can't confirm). Show an info toast: *"Log it from Interactions once sent."* (Do **not** silently log — that reintroduces the false-positive the whole change avoids.)
- **Text tap:** same shape with `MessageComposeView` + `canSendText()` fallback to `smsURL()`.

Success toast copy (parity with web wording): **"Logged email to Coach {fullName}."** / **"Logged text to Coach {fullName}."** — type `.success`. Present on the parent (`CoachesListView` already shows toasts at `:73`) after the sheet dismisses, or inside the sheet before dismiss — implementer's choice; prefer parent so it survives dismissal.

### 5. `last_contact_date` write (parity)
Web sets `last_contact_date` on the coach after logging. iOS has **no** app-side path (`CoachUpdateRequest` lacks the field).
- Add `lastContactDate: String?` → `CoachUpdateRequest` with `case lastContactDate = "last_contact_date"`.
- `updateLastContactDate()` calls `CoachesManaging.updateCoach(coachId, CoachUpdateRequest(lastContactDate: ISO8601 now))`.
- **First verify** whether a DB trigger already sets `last_contact_date` on `interactions` insert. If yes, skip task 5 entirely (logging suffices). If no, implement it. Do not double-write.

### 6. Tests
`.../TheRecruitingCompassTests/...` — mock `InteractionsManaging`:
- `.sent` result → `createInteraction` called once with `type == "email"`, `direction == "outbound"`, `coachId == coach.id`.
- `.cancelled` / `.saved` / `.failed` → `createInteraction` **not** called.
- `canSendMail() == false` fallback path → `createInteraction` **not** called (log-nothing guarantee).
- If task 5 implemented: `updateCoach` called with `lastContactDate` on `.sent` only.

## Out of scope / notes
- No undo, no Toast action-button extension (iOS never logs an unsent message, so nothing to undo).
- No optimistic insert — the whole point of using MessageUI is to avoid it.
- Fallback path (no Mail/Messages account) intentionally logs nothing; acceptable — it's the same fire-and-forget the app has today, minus the false "sent."
- Verify `InteractionType` raw values are `"email"` / `"text"` to match the web `interactions.type` domain before shipping.

## Build gate
`xcodebuild build` clean + new unit tests green before merge. This spec is unverified against a compiler (authored from the web session) — treat compile errors as expected first-pass fixes, not design changes.
