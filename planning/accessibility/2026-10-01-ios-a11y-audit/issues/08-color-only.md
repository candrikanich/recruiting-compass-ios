## Problem

A few places convey meaning by colour alone, with no text, icon or shape and no VoiceOver equivalent. The app has zero uses of `accessibilityDifferentiateWithoutColor`. WCAG 1.4.1 (Use of Color).

Most status in the app is done well — badges for event type, offer status, deadline urgency, password strength and task status all carry text. These are the exceptions:

| Where | What is colour-only |
|---|---|
| `Features/Timeline/Components/TimelineStatPills.swift:16-35`, `Features/Dashboard/Components/DashboardTimelineSummaryCard.swift:38-46,101-107`, `Features/Timeline/Models/StatusLabel.swift:4-8` | Recruiting status (on track / slightly behind / at risk) is only a tint on an icon and a 10 pt dot. `StatusLabel` has no display string; VoiceOver hears "Status score N out of 100". |
| `Features/Schools/.../PersonalFitCard.swift:37`, colour map `:51-59` | Fit strength (strong / good / stretch) is only the badge colour; the badge text is the signal name. `AcademicFitCard.swift:55` does it correctly. |
| `Features/Family/Views/ParentOnboardingWizardView.swift:88-94` | The under-13 error is unchanged helper text turned red. The disabled "Get Started" gives no reason, and the intro says name is optional while validation requires it (`ParentOnboardingWizardViewModel.swift:71-80`). |
| `Features/Offers/Components/ScholarshipCalculatorView.swift:160-186` | Year breakdown has no column headers; scholarship vs additional aid differ only by green vs blue. |
| `Features/Deadlines/Components/DeadlinesCalendarGridView.swift:50-57` | Category shown as up to three 5 pt coloured dots; the label gives only a count. |
| `Features/Analytics/Components/PieChartView.swift:84-104` | Slices map to legend rows only by a 10 pt colour dot. |
| `Features/Notifications/Components/NotificationCard.swift:32-33,62-68` | Read vs unread differ by colour and weight only (VoiceOver label is fine). |
| `Features/Events/Components/EventsCalendarView.swift:107-128,137-144` | Selected day and today are fills only; no trait or text. |
| `Features/Guardian/Views/GuardianPendingBanner.swift:37-41` | Resend success and failure use the same blue text. |

## Fix

- Add `StatusLabel.displayName` ("On Track", "Slightly Behind", "At Risk"), show it as text with a distinct SF Symbol per state, and append it to both accessibility labels.
- Add a text label to `FitSignalStrength` and render it ("Location · Strong").
- Parent onboarding: explicit error row (icon + "Player must be 13 or older"), announced; mark required fields; correct the intro copy; add a hint on the disabled button.
- Scholarship breakdown: header row (Cost / Scholarship / Aid / You pay).
- Calendar cells: include category names and "Today"/selected in the label; add `.isSelected`.
- Pie chart: order the legend to match slice order and add direct labels or patterns under `accessibilityDifferentiateWithoutColor`.

## Done when

Each item above can be understood in greyscale and is spoken by VoiceOver.

## Evidence

Confirmed by reading the source; not checked on device. Severity: **High** for recruiting status, Personal Fit and parent onboarding; Medium for the rest.

Part of the iOS accessibility audit — tracking issue: TRACKING
