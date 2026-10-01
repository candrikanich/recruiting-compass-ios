## Problem

On Recruiting Timeline, each phase card is a single VoiceOver element, including after it is expanded. The task rows inside it cannot be read or completed with VoiceOver.

`Features/Timeline/Components/PhaseCard.swift:98-100` wraps the header button **and** the expanded task list:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel(String(localized: "\(phase.displayLabel), \(completedCount) of \(totalCount) tasks complete"))
.accessibilityHint("Double tap to expand or collapse")
```

The explicit label replaces everything the children would have said, so an expanded phase still reads only "Junior Year, 3 of 8 tasks complete".

The task rows have their own problems that will surface once the card is fixed (`Features/Timeline/Components/PhaseCardTaskRow.swift`):

- `:35-48` — the checkbox `Button` is an SF Symbol with no `accessibilityLabel`.
- `:128-141`, `:161-166` — every badge is `.accessibilityHidden(true)` and the row label is only title, category, required and status. "Locked", "Recovery", "Overdue / Due Soon" and "Due This Week" are never spoken.
- `:68-82` — the expanded description, "Why It Matters" and "Don't Miss This" text is overridden by the row label.
- The row has both a checkbox button and an `onTapGesture` expander. The hint says "Double tap to show details"; nothing tells the user how to mark a task complete.

## Fix

1. Move combine/label/hint onto the header `Button` only (`PhaseCard.swift:26-71`) and add `.accessibilityValue(isExpanded ? "Expanded" : "Collapsed")`. Leave the task rows as separate elements.
2. Task row: build the label from every visible fact (locked, recovery, deadline urgency); add `.accessibilityAction(named: "Mark complete")` and `.accessibilityAction(named: "Show details")`; label the checkbox "Mark <title> complete".
3. The unreachable `Features/Tasks/Views/TasksListView.swift` and `TaskCard.swift:101-113` carry the same pattern — delete the dead screen or fix it alongside.

## Done when

With VoiceOver, a user can expand a phase, hear each task's title, status and urgency, and mark one complete.

## Evidence

Confirmed by reading the source. Not confirmed on device: the automated run could not load Timeline because it needs the local web API, which was not running. Severity: **Blocker**.

Part of the iOS accessibility audit — tracking issue: TRACKING
