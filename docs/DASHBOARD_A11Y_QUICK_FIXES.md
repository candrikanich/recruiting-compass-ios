# Dashboard Accessibility - Quick Fix Guide

**Priority:** CRITICAL (8 blocking issues)
**Estimated Time:** 8-12 hours
**Test Method:** VoiceOver + Keyboard Navigation

---

## 1. DashboardView.swift - Navigation Links (Lines 114-191)

**Problem:** 6 stat card links have no accessibility context
**Impact:** Screen readers say "button" with no action description

```swift
// BEFORE - NO ACCESSIBILITY
NavigationLink(value: DashboardDestination.coaches) {
  StatCard(title: "Coaches", count: stats.coachCount, ...)
}
.buttonStyle(PlainButtonStyle())

// AFTER - WITH ACCESSIBILITY
NavigationLink(value: DashboardDestination.coaches) {
  StatCard(title: "Coaches", count: stats.coachCount, ...)
}
.accessibilityLabel("View all coaches")
.accessibilityHint("Opens a list of all your coaches")
.buttonStyle(PlainButtonStyle())
```

**Apply to all 6 stat cards:**
- `.coaches` → "View all coaches"
- `.schools` → "View all schools"
- `.interactions` → "View all interactions"
- `.offers` → "View all offers"
- `.accepted` → "View accepted offers"
- `.aTier` → "View A-Tier schools"

---

## 2. QuickTaskWidget.swift - "Add" Button (Line 40)

**Problem:** Button has no label or hint

```swift
// BEFORE
Button("Add") {
  submitTask()
}
.disabled(newTaskText.isEmpty)

// AFTER
Button("Add") {
  submitTask()
}
.disabled(newTaskText.isEmpty)
.accessibilityLabel("Add task")
.accessibilityHint("Add the task from the text field above")
```

---

## 3. QuickTaskWidget.swift - TextField (Line 33)

**Problem:** Only has placeholder text (not accessible)

```swift
// BEFORE
TextField("Add a task...", text: $newTaskText)
  .focused($isInputFocused)
  .textFieldStyle(RoundedBorderTextFieldStyle())
  .onSubmit { submitTask() }

// AFTER
TextField("Add a task...", text: $newTaskText)
  .focused($isInputFocused)
  .textFieldStyle(RoundedBorderTextFieldStyle())
  .accessibilityLabel("Task text field")
  .accessibilityHint("Type a task name. Press return to add or use the Add button.")
  .onSubmit { submitTask() }
```

---

## 4. Show More Buttons - 3 FILES (Empty Action Handlers)

**Files:**
- UpcomingEventsWidget.swift (Line 30)
- RecentActivityFeed.swift (Line 30)
- PerformanceMetricsWidget.swift (Line 30)

**Problem:** Buttons do nothing (empty closure `{}`)

```swift
// BEFORE - BROKEN BUTTON
Button("Show \(count - 3) more events") {
}  // EMPTY!
.font(.caption)
.foregroundColor(Color.accentBlue)

// AFTER - WORKING NAVIGATION
NavigationLink(value: DashboardDestination.events) {
  Text("Show \(count - 3) more events")
}
.font(.caption)
.foregroundColor(Color.accentBlue)
.accessibilityLabel("View all events")
.accessibilityHint("Opens a complete list of upcoming events")
```

---

## 5. QuickTaskWidget.swift - "Clear Completed" (Line 22)

**Problem:** Destructive action not marked

```swift
// BEFORE
Button("Clear Completed") {
  onClearCompleted()
}
.font(.caption)
.foregroundColor(Color.accentBlue)

// AFTER
Button("Clear Completed") {
  onClearCompleted()
}
.font(.caption)
.foregroundColor(Color.accentBlue)
.accessibilityLabel("Clear completed tasks")
.accessibilityHint("Deletes all completed tasks. This action cannot be undone.")
.accessibilityAddTraits(.isDangersButton)
```

---

## 6. StatCardSkeleton.swift - Loading State (Line 3-30)

**Problem:** No accessibility label during loading

```swift
// BEFORE
struct StatCardSkeleton: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // ... shapes
    }
  }
}

// AFTER
struct StatCardSkeleton: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // ... shapes
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Loading statistics")
    .accessibilityAddTraits([.updatesFrequently])
  }
}
```

---

## 7. InteractionTrendsChart.swift - Chart Data (Line 20-36)

**Problem:** Chart has no text alternative for blind/low vision users

```swift
// BEFORE - NO ALTERNATIVE
Chart(trends) { trend in
  BarMark(...)
  .foregroundStyle(Color.primaryGreen.gradient)
}

// AFTER - WITH ACCESSIBILITY
Chart(trends) { trend in
  BarMark(...)
  .foregroundStyle(Color.primaryGreen.gradient)
  .accessibilityLabel("Interactions on \(trend.dateFormatted)")
  .accessibilityValue("\(trend.count) interactions")
}
.accessibilityLabel("Bar chart: Interaction trends over time")
.accessibilityValue("Latest data: \(trends.last?.count ?? 0) interactions")

// ADD TEXT SUMMARY BELOW CHART
Text("Summary: \(totalInteractions) total interactions in this period")
  .font(.caption)
  .foregroundColor(Color.secondaryText)
  .accessibilityAddTraits(.isSummaryElement)
```

---

## 8. ActionItemsWidget.swift - Action Buttons (Line 74-88)

**Problem:** Complete vs. Dismiss buttons lack context

```swift
// BEFORE - CONFUSING
Button(action: onComplete) {
  Image(systemName: "checkmark.circle.fill")
    .foregroundColor(Color.accentBlue)
}
.accessibilityLabel("Complete suggestion")

// AFTER - CLEAR DISTINCTION
Button(action: onComplete) {
  Image(systemName: "checkmark.circle.fill")
    .foregroundColor(Color.accentBlue)
    .frame(minWidth: 44, minHeight: 44)
    .contentShape(Rectangle())
}
.accessibilityLabel("Complete action: \(suggestion.title)")
.accessibilityHint("Mark this suggestion as complete")
```

---

## Testing After Fixes

### VoiceOver Test (Cmd+F5)
1. Tap each stat card
2. Verify: "View all [name]. Opens a list of all your [name]s. Button."
3. Test Add button: "Add task. Add the task from the text field above. Button."
4. Test text field: "Task text field. Type a task name... Text field."

### Keyboard Test
1. Press Tab to navigate
2. Verify all buttons are reachable
3. Press Return to activate
4. Verify action works

### Verification Script
```bash
# Run this after making changes
cd /Users/chrisandrikanich/Documents/Workspaces/Personal/TheRecruitingCompass/recruiting-compass-ios-fresh/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## Implementation Order

1. **Start with QuickTaskWidget** (3 issues = 30 min)
   - Add button
   - Text field
   - Clear completed
   
2. **Move to DashboardView** (1 issue = 30 min)
   - 6 stat card navigation links

3. **Fix Show More buttons** (3 files = 20 min)
   - UpcomingEventsWidget
   - RecentActivityFeed
   - PerformanceMetricsWidget

4. **Add skeleton loader label** (5 min)
   - StatCardSkeleton

5. **Implement chart alternative** (30 min)
   - InteractionTrendsChart

6. **Fix action buttons** (15 min)
   - ActionItemCard complete/dismiss distinction

7. **Test thoroughly** (2 hours)
   - VoiceOver
   - Keyboard navigation
   - Dynamic Type

---

## Files to Modify (in order)

```
Priority 1 (First Sprint):
  /TheRecruitingCompass/Features/Dashboard/Components/QuickTaskWidget.swift
  /TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift
  /TheRecruitingCompass/Features/Dashboard/Components/UpcomingEventsWidget.swift
  /TheRecruitingCompass/Features/Dashboard/Components/RecentActivityFeed.swift
  /TheRecruitingCompass/Features/Dashboard/Components/PerformanceMetricsWidget.swift
  /TheRecruitingCompass/Features/Dashboard/Components/StatCardSkeleton.swift
  /TheRecruitingCompass/Features/Dashboard/Components/InteractionTrendsChart.swift
  /TheRecruitingCompass/Features/Dashboard/Components/ActionItemsWidget.swift
```

---

## Common Patterns Used

### Pattern 1: Accessibility Label + Hint
```swift
Button("Action") { }
.accessibilityLabel("Clear label of what button does")
.accessibilityHint("Additional context or explanation")
```

### Pattern 2: Grouped Content
```swift
HStack { /* content */ }
.accessibilityElement(children: .combine)
.accessibilityLabel("Label for group")
.accessibilityValue("Value for group")
```

### Pattern 3: Text Field Labeling
```swift
TextField("placeholder", text: $text)
.accessibilityLabel("Field name")
.accessibilityHint("How to use this field")
```

### Pattern 4: Destructive Actions
```swift
Button("Delete") { }
.accessibilityAddTraits(.isDangersButton)
.accessibilityHint("Deletes permanently. Cannot be undone.")
```

### Pattern 5: Loading/Status
```swift
view
.accessibilityLabel("Loading data")
.accessibilityAddTraits(.updatesFrequently)
```

---

## Verification Checklist

- [ ] All 8 critical issues addressed
- [ ] Project builds without errors
- [ ] VoiceOver announces all buttons correctly
- [ ] Tab navigation works through all elements
- [ ] "Show More" buttons are now functional
- [ ] Destructive actions properly marked
- [ ] Chart has text alternative
- [ ] Loading state announces to screen readers

---

## Reference Links

- [Apple Accessibility Documentation](https://developer.apple.com/accessibility/swiftui/)
- [WCAG 2.1 Level AA](https://www.w3.org/WAI/WCAG21/quickref/)
- [iOS Accessibility Inspector](https://developer.apple.com/documentation/accessibility/accessibilityinspector)

---

**Status:** Research Only - No Changes Made
**Next Step:** Follow these fixes and verify with VoiceOver testing
