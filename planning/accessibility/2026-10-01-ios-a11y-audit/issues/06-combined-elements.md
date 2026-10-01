## Problem

Many rows and cards apply `.accessibilityElement(children: .combine)` plus an explicit `.accessibilityLabel` to a container that holds buttons or important text. The explicit label replaces what the children said, so buttons lose their names (or become unreachable) and visible information is never spoken. The app has **zero** `accessibilityAction` uses, so nothing replaces the swallowed controls.

The project `CLAUDE.md` currently says "Form fields grouped with `.accessibilityElement(children: .combine)`" — that rule encourages this pattern and should be reworded to cover read-only rows only.

### A. Containers that swallow buttons

| Where | What is lost |
|---|---|
| `Shared/Components/Forms/FormFieldWrapper.swift:55-56` (20 call sites: `CoachFormView` ×10, `SchoolFormView` ×10) | Label, text field/picker and error merged into one element; per-field labels and hints discarded. For the Tags field (`CoachFormView.swift:63-71`) every "Remove tag" and "Add tag" button is merged under "Tags". On the simulator, each Add School field appears as a generic element labelled e.g. "School Name, required" whose value is the placeholder, with an unlabelled text field beneath it — so it is not exposed as a text field. Whether activating it starts editing is not verified. |
| `Features/Coaches/Views/QuickCommunicationView.swift:610-626` | Same pattern around a `TextField` |
| `Features/Schools/.../SchoolCoachingPhilosophySheet.swift:115-117` | `TextEditor` merged; value replaced with "Empty"/text |
| `Features/Family/Components/FamilyMemberCard.swift:59-73` | "Remove <name>" button |
| `Features/Family/Components/ForwardCoachEmailsCard.swift:10-46` | "Copy forwarding address" button, plus the explanatory paragraph |
| `Features/Performance/Components/MetricHistoryCard.swift:40-70,108-113` | Star / Edit / Delete |
| `Features/Auth/Components/Banner.swift:55-70` (used by Login, Dashboard, Performance) | "Close message" button; `LoginView.swift:111-126` also adds a wrong `.isHeader` |
| `Features/Tasks/Components/TasksParentBanner.swift:47-48` | "Exit preview mode" button (`ParentPreviewBanner.swift:47` does it correctly with `.contain`) |
| `Features/Notifications/Components/NotificationCard.swift:23,53-59,72-77` | Nested "Delete notification" button; `onMarkRead` is never wired up |
| `Shared/Components/Forms/FormErrorSummary.swift:16,59-67` | "Dismiss error summary" button |
| `Features/Dashboard/Views/MoreMenuView.swift:125` vs `:173` | Outer link label overrides the row label, so the description and the "N unread" count are never spoken |

### B. Buttons nested inside a tappable card

Checked on the simulator, and **the two main lists are fine**: the Schools list card and the Coaches list card each expose one button with a full composed label ("Clemson University, Clemson, SC, D1, Contacted, Personal fit: Stretch, Conference: ACC") plus separate "Delete <school>", "Add to favorites" and "Email coach" buttons. No change needed there.

Not checked on device (same structure, different code path):

- Coach rows inside school detail: `SchoolCoachesPanel.swift:65-75` wrapping `CoachCardView.swift:43-47`.
- Offers list: `OffersListView.swift:164-176` wraps `OfferCard.swift:18-31,85-100` (checkbox + delete inside a `NavigationLink`).

### C. Labels that drop or replace visible information

- Deadline rows never speak the date: `Features/Deadlines/Components/DeadlineRow.swift:94-97`.
- Action-item urgency is `.accessibilityHidden(true)`: `Features/Dashboard/Components/ActionItemCard.swift:27-41`.
- Coach follow-up row drops school and days since contact: `Features/Dashboard/Components/CoachFollowupRow.swift:12-25`.
- Document upload label is fixed to "Select file", hiding the chosen file name: `Features/Documents/Components/DocumentUploadSheet.swift:57-68`.
- Unit text replaced by "Unit of measurement": `Features/Performance/Components/MetricFormView.swift:121-127`.
- Timeout banner explanation replaced by "Session timeout warning": `Features/Auth/Components/TimeoutBanner.swift:10-11`.
- Event rows speak the raw `official_visit` type and drop location: `Features/Dashboard/Components/EventRow.swift:89-91`; `Features/Events/Views/EventsListView.swift:261,314-320` omits time, place, cost.
- Document cards omit school and version: `DocumentCardView.swift:94-96`, `DocumentListViewRow.swift:92-94`. Offer checkbox has no school name: `OfferCard.swift:110`.
- Documents sort menu hides the current sort: `DocumentFilterBar.swift:14-33`.
- Calendar day label is the raw ISO string: `DeadlinesCalendarGridView.swift:68-72`.
- Text-field value replaced by the error string: `Features/Auth/Components/LoginFormField.swift:47-48`, `PasswordFormField.swift:29-30` (verify on device whether typed text is still read).

## Fix

- Never put `.combine` + a label override on a container that holds a control. Combine only the text block and leave buttons as siblings, **or** keep one element and add `.accessibilityAction(named:)` for each swallowed control.
- `FormFieldWrapper`: remove `.combine` and the override; hide the visual label (`.accessibilityHidden(true)`), put the label (+ ", required") on the control, attach the error via hint or leave `FieldError` as the next element.
- Build explicit labels from the same data the row shows; use `accessibilityValue` for the part that changes.
- Reword the `CLAUDE.md` rule.

## Done when

Each listed control is reachable by name with VoiceOver and Voice Control, and each row's spoken label contains everything the row shows.

## Evidence

Every listed pattern is confirmed in source (several re-read during consolidation). What VoiceOver does with each merged container — child button becomes a default activation, a rotor action, or nothing — is **not** verified on a device, which is why this is High rather than Blocker. Severity: **High**.

Part of the iOS accessibility audit — tracking issue: TRACKING
