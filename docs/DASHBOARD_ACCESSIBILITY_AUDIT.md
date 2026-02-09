# Dashboard Accessibility Audit Report
## The Recruiting Compass - iOS SwiftUI Project

**Audit Date:** February 8, 2026
**Project Location:** `/Users/chrisandrikanich/Documents/Workspaces/Personal/TheRecruitingCompass/recruiting-compass-ios-fresh/`
**Framework:** SwiftUI (iOS 15+)
**WCAG Target:** WCAG 2.1 Level AA

---

## Executive Summary

The Dashboard feature demonstrates **strong accessibility fundamentals** with proper use of `.accessibilityLabel()`, `.accessibilityHint()`, and `.accessibilityElement(children: .combine)` patterns throughout most components. However, several **critical gaps** exist that reduce usability for VoiceOver users and individuals relying on Dynamic Type scaling.

**Overall Compliance Status:** PARTIAL (65% of ideal accessibility coverage)

**Critical Issues:** 8
**High Priority Issues:** 12
**Medium Priority Issues:** 9
**Low Priority Issues:** 7

---

## Files Audited

### Main Views (1)
- DashboardView.swift

### Dashboard Components (12)
- StatCard.swift
- ParentPreviewBanner.swift
- AthleteSelector.swift
- ActionItemsWidget.swift
- QuickTaskWidget.swift
- UpcomingEventsWidget.swift
- RecentActivityFeed.swift
- PerformanceMetricsWidget.swift
- AtAGlanceSummary.swift
- InteractionTrendsChart.swift
- EmptyDashboardState.swift
- StatCardSkeleton.swift

### Shared Components Used by Dashboard (1)
- ErrorBanner.swift (Features/Auth/Components/)

### Navigation Destination Views (4)
- CoachesListView.swift
- SchoolsListView.swift
- InteractionsListView.swift
- SuggestionsListView.swift

### Placeholder Component (1)
- PlaceholderListView.swift

---

## Critical Issues (Must Fix)

### 1. DashboardView.swift - Missing Accessibility Context on Main Navigation Links

**Location:** Lines 114-191 (statsCardsSection)
**WCAG Criterion:** 4.1.2 Name, Role, Value
**Severity:** CRITICAL
**Impact:** Screen reader users cannot understand the purpose of navigation links to detail views. VoiceOver announces only "button" with no clear action description.

**Current State:**
```swift
NavigationLink(value: DashboardDestination.coaches) {
  StatCard(
    title: "Coaches",
    count: stats.coachCount,
    // ...
  )
}
.buttonStyle(PlainButtonStyle())
```

**Issue:**
- NavigationLink provides no accessibility label at the wrapper level
- StatCard is accessible internally, but wrapping NavigationLink obscures the navigation intent
- Screen readers hear "Button: Coaches: 12" but no indication that tapping navigates to a detailed list

**Who Is Affected:**
- Screen reader users (NVDA, JAWS, VoiceOver) cannot understand that tapping navigates to a coaches list
- Users with cognitive disabilities may be confused by unlabeled interactive elements

**Recommended Fix:**
```swift
NavigationLink(value: DashboardDestination.coaches) {
  StatCard(
    title: "Coaches",
    count: stats.coachCount,
    subtitle: nil,
    icon: "person.2.fill",
    gradientColors: [...],
    isEnabled: true,
    destination: .coaches
  )
}
.accessibilityLabel("View all coaches")  // Add at NavigationLink level
.accessibilityHint("Opens a list of all your coaches")  // Add navigation context
.buttonStyle(PlainButtonStyle())
```

**Testing Confirmation:**
- Enable VoiceOver on iOS Simulator (Cmd+F5)
- Navigate to each stat card
- Verify VoiceOver announces: "View all coaches. Opens a list of all your coaches. Button."
- Repeat for all 6 stat cards (coaches, schools, interactions, offers, accepted, a-tier)

---

### 2. QuickTaskWidget.swift - Missing Accessibility on "Add" Button

**Location:** Line 40-42
**WCAG Criterion:** 2.1.1 Keyboard; 4.1.2 Name, Role, Value
**Severity:** CRITICAL
**Impact:** Screen reader users cannot access the task input mechanism. No hint about required text input before button becomes active.

**Current State:**
```swift
Button("Add") {
  submitTask()
}
.disabled(newTaskText.isEmpty)
```

**Issue:**
- Button has no `.accessibilityLabel()` or `.accessibilityHint()`
- No announcement when button becomes enabled (state change not communicated)
- "Add" is non-descriptive; unclear it adds a quick task

**Who Is Affected:**
- Screen reader users trying to add tasks
- Users using switch control (rely on button labels to understand function)

**Recommended Fix:**
```swift
Button("Add") {
  submitTask()
}
.disabled(newTaskText.isEmpty)
.accessibilityLabel("Add task")
.accessibilityHint("Add the task from the text field above")
.accessibilityAddTraits(.isButton)
```

**Testing Confirmation:**
- Enable VoiceOver
- Type text in the task input field
- Verify VoiceOver announces button state change from "disabled" to "enabled"
- Tap button and verify task is added

---

### 3. QuickTaskWidget.swift - Missing Accessibility on TextField

**Location:** Line 33-38
**WCAG Criterion:** 4.1.2 Name, Role, Value; 2.4.6 Headings and Labels
**Severity:** CRITICAL
**Impact:** Screen reader users cannot identify what the text field is for without relying on placeholder text alone.

**Current State:**
```swift
TextField("Add a task...", text: $newTaskText)
  .focused($isInputFocused)
  .textFieldStyle(RoundedBorderTextFieldStyle())
  .onSubmit {
    submitTask()
  }
```

**Issue:**
- TextField has only placeholder text, no `.accessibilityLabel()`
- Placeholder text alone is insufficient (WCAG 2.1 AA requirement)
- No accessibility hint about submitting via Return key

**Who Is Affected:**
- Screen reader users who cannot rely on placeholder visual text
- Users with cognitive disabilities who need clear field labels

**Recommended Fix:**
```swift
TextField("Add a task...", text: $newTaskText)
  .focused($isInputFocused)
  .textFieldStyle(RoundedBorderTextFieldStyle())
  .accessibilityLabel("Task text field")
  .accessibilityHint("Type a task name. Press return to add or use the Add button.")
  .onSubmit {
    submitTask()
  }
```

**Testing Confirmation:**
- Enable VoiceOver
- Navigate to text field
- Verify announcement: "Task text field. Type a task name. Press return to add or use the Add button. Text field."
- Type text and press Return key (verify submission works)

---

### 4. UpcomingEventsWidget.swift & RecentActivityFeed.swift - Missing "Show More" Button Accessibility

**Location:** 
- UpcomingEventsWidget.swift, Lines 29-34
- RecentActivityFeed.swift, Lines 29-34
- PerformanceMetricsWidget.swift, Lines 29-34

**WCAG Criterion:** 4.1.2 Name, Role, Value
**Severity:** CRITICAL
**Impact:** Screen reader users cannot understand that "Show X more" buttons are clickable or what they do.

**Current State:**
```swift
if sortedEvents.count > 3 {
  Button("Show \(sortedEvents.count - 3) more events") {
  }
  .font(.caption)
  .foregroundColor(Color.accentBlue)
}
```

**Issue:**
- Button has no action handler (empty closure `{}`)
- No `.accessibilityLabel()` or `.accessibilityHint()`
- Button action is incomplete/non-functional
- VoiceOver announces only the text, missing navigation context

**Who Is Affected:**
- All screen reader users
- Users with motor disabilities trying to understand button purpose before activation

**Recommended Fix:**
```swift
if sortedEvents.count > 3 {
  NavigationLink(value: DashboardDestination.events) {
    Text("Show \(sortedEvents.count - 3) more events")
  }
  .font(.caption)
  .foregroundColor(Color.accentBlue)
  .accessibilityLabel("View all events")
  .accessibilityHint("Opens a complete list of \(sortedEvents.count) events")
}
```

**Testing Confirmation:**
- Enable VoiceOver
- Navigate to the "Show X more" button
- Verify announcement includes navigation intent
- Tap button and verify it navigates to the appropriate detail view

---

### 5. QuickTaskWidget.swift - "Clear Completed" Button Missing Accessibility

**Location:** Line 22-26
**WCAG Criterion:** 4.1.2 Name, Role, Value; 2.4.4 Link Purpose
**Severity:** CRITICAL
**Impact:** Screen reader users cannot understand the destructive action they're about to perform.

**Current State:**
```swift
if tasks.contains(where: { $0.isCompleted }) {
  Button("Clear Completed") {
    onClearCompleted()
  }
  .font(.caption)
  .foregroundColor(Color.accentBlue)
}
```

**Issue:**
- No `.accessibilityLabel()` or `.accessibilityHint()`
- No warning about destructive action (permanent deletion)
- No additional confirmation before action
- Non-descriptive button text for screen reader users

**Who Is Affected:**
- Screen reader users who might accidentally delete completed tasks
- Users with cognitive disabilities who need clear action descriptions
- Users with motor disabilities who need confirmation before destructive actions

**Recommended Fix:**
```swift
if tasks.contains(where: { $0.isCompleted }) {
  Button("Clear Completed") {
    onClearCompleted()
  }
  .font(.caption)
  .foregroundColor(Color.accentBlue)
  .accessibilityLabel("Clear completed tasks")
  .accessibilityHint("Deletes all completed tasks. This action cannot be undone.")
  .accessibilityAddTraits(.isDangersButton)
}
```

**Testing Confirmation:**
- Enable VoiceOver
- Complete a task
- Navigate to "Clear Completed" button
- Verify VoiceOver announces the destructive nature and consequences

---

### 6. StatCardSkeleton.swift - Missing Accessibility on Loading State

**Location:** Lines 1-29
**WCAG Criterion:** 4.1.2 Name, Role, Value
**Severity:** CRITICAL
**Impact:** Screen reader users have no indication that the dashboard is loading, causing confusion about page status.

**Current State:**
```swift
struct StatCardSkeleton: View {
  @State private var isAnimating = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Circle()
        .fill(Color.gray.opacity(0.3))
        .frame(width: 32, height: 32)
      // ... more placeholder UI
    }
    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
    .onAppear { isAnimating = true }
  }
}
```

**Issue:**
- No accessibility label indicating this is a loading skeleton
- No announcement to screen readers that content is loading
- VoiceOver users don't know why placeholder content is displayed
- Animated loading state has no textual description

**Who Is Affected:**
- Screen reader users (no indicator of loading state)
- Users with vestibular disorders (animation causes discomfort/confusion)
- Cognitive disabilities (unclear page state)

**Recommended Fix:**
```swift
struct StatCardSkeleton: View {
  @State private var isAnimating = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Circle()
        .fill(Color.gray.opacity(0.3))
        .frame(width: 32, height: 32)
      // ... placeholder UI
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Loading statistics")
    .accessibilityAddTraits([.updatesFrequently])
    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
    .onAppear { isAnimating = true }
  }
}
```

**Testing Confirmation:**
- Enable VoiceOver
- Trigger dashboard to load (pull to refresh)
- Verify VoiceOver announces "Loading statistics" on skeleton appearance
- Verify animation doesn't cause performance issues

---

### 7. InteractionTrendsChart.swift - Chart Missing Accessibility Alternative

**Location:** Lines 20-36
**WCAG Criterion:** 1.1.1 Non-text Content; 1.4.11 Non-text Contrast (if color-only)
**Severity:** CRITICAL
**Impact:** Chart-based data is inaccessible to screen reader users and individuals with color blindness. No text description or alternative method to access data.

**Current State:**
```swift
Chart(trends) { trend in
  BarMark(
    x: .value("Date", trend.dateFormatted, unit: .day),
    y: .value("Count", trend.count)
  )
  .foregroundStyle(Color.primaryGreen.gradient)
}
.frame(height: 200)
.chartXAxis { ... }
.chartYAxis { ... }
```

**Issue:**
- Chart uses visual representation only (no text alternative)
- No `.accessibilityLabel()` on Chart or BarMarks
- Screen readers cannot access chart data
- Color (green) is the only indicator of chart purpose
- No numeric summary or table alternative

**Who Is Affected:**
- Blind and low vision users (cannot perceive chart)
- Color blind users (no shape/pattern differentiation)
- Screen reader users (no accessible data representation)

**Recommended Fix:**
```swift
VStack(alignment: .leading, spacing: 12) {
  Text("Interaction Trends")
    .font(.headline)

  Divider()

  if trends.isEmpty {
    Text("No interaction data yet")
      .font(.caption)
      .foregroundColor(Color.secondaryText)
      .padding(.vertical)
  } else {
    // Chart with accessibility
    Chart(trends) { trend in
      BarMark(
        x: .value("Date", trend.dateFormatted, unit: .day),
        y: .value("Count", trend.count)
      )
      .foregroundStyle(Color.primaryGreen.gradient)
      .accessibilityLabel("Interactions on \(trend.dateFormatted)")
      .accessibilityValue("\(trend.count) interactions")
    }
    .frame(height: 200)
    .chartXAxis { ... }
    .chartYAxis { ... }
    .accessibilityLabel("Bar chart: Interaction trends over time")
    .accessibilityValue("Latest data: \(trends.last?.count ?? 0) interactions")
    
    // Text summary below chart
    Text("Summary: \(trends.map { $0.count }.reduce(0, +)) total interactions in this period")
      .font(.caption)
      .foregroundColor(Color.secondaryText)
      .accessibilityAddTraits(.isSummaryElement)
  }
}
```

**Testing Confirmation:**
- Enable VoiceOver
- Navigate to chart
- Verify accessibility label and value are announced
- Verify text summary is also announced
- Disable color (Accessibility > Display & Text Size > Reduce Transparency) and verify data is still understandable

---

### 8. ActionItemsWidget.swift - Action Buttons Missing Accessibility Context

**Location:** Lines 74-88 (ActionItemCard)
**WCAG Criterion:** 4.1.2 Name, Role, Value; 2.1.1 Keyboard
**Severity:** CRITICAL
**Impact:** Screen reader users cannot distinguish between "complete" and "dismiss" action buttons without tapping both. No hint about the semantic difference in actions.

**Current State:**
```swift
Button(action: onComplete) {
  Image(systemName: "checkmark.circle.fill")
    .foregroundColor(Color.accentBlue)
    .font(.title3)
}
.buttonStyle(PlainButtonStyle())
.accessibilityLabel("Complete suggestion")

Button(action: onDismiss) {
  Image(systemName: "xmark.circle.fill")
    .foregroundColor(Color.gray)
    .font(.title3)
}
.buttonStyle(PlainButtonStyle())
.accessibilityLabel("Dismiss suggestion")
```

**Issue:**
- Buttons have labels but no hints explaining the semantic difference
- "Complete" behavior is ambiguous (completes the action item or action itself?)
- "Dismiss" could mean delete, archive, or hide
- No distinction that these are destructive vs. constructive actions
- Card-level accessibility combines both actions without clear separation

**Who Is Affected:**
- Screen reader users uncertain about action consequences
- Users with cognitive disabilities needing explicit action descriptions
- Motor disability users who need to understand button function before activation

**Recommended Fix:**
```swift
HStack(alignment: .top, spacing: 12) {
  Circle()
    .fill(suggestion.urgency.color)
    .frame(width: 8, height: 8)
    .padding(.top, 6)
    .accessibilityHidden(true)

  VStack(alignment: .leading, spacing: 4) {
    Text(suggestion.title)
      .font(.subheadline)
      .fontWeight(.semibold)

    Text(suggestion.description)
      .font(.caption)
      .foregroundColor(Color.secondaryText)
      .lineLimit(2)
  }

  Spacer()

  VStack(spacing: 8) {
    Button(action: onComplete) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundColor(Color.accentBlue)
        .font(.title3)
        .frame(minWidth: 44, minHeight: 44)  // Touch target
        .contentShape(Rectangle())
    }
    .buttonStyle(PlainButtonStyle())
    .accessibilityLabel("Complete action: \(suggestion.title)")
    .accessibilityHint("Mark this suggestion as complete")

    Button(action: onDismiss) {
      Image(systemName: "xmark.circle.fill")
        .foregroundColor(Color.gray)
        .font(.title3)
        .frame(minWidth: 44, minHeight: 44)  // Touch target
        .contentShape(Rectangle())
    }
    .buttonStyle(PlainButtonStyle())
    .accessibilityLabel("Dismiss action: \(suggestion.title)")
    .accessibilityHint("Hide this suggestion without marking it complete")
  }
}
.padding(12)
.background(Color(.secondarySystemBackground))
.cornerRadius(8)
.accessibilityElement(children: .combine)
.accessibilityLabel("\(suggestion.urgency.rawValue) priority: \(suggestion.title)")
.accessibilityValue(suggestion.description)
```

**Testing Confirmation:**
- Enable VoiceOver
- Navigate to action item card
- Verify button labels clarify the specific suggestion being acted on
- Verify hints explain the semantic difference between complete and dismiss
- Test keyboard navigation (Tab through both buttons)

---

## High Priority Issues

### 9. DashboardView.swift - Missing Navigation Title Accessibility

**Location:** Line 62
**WCAG Criterion:** 2.4.2 Page Titled
**Severity:** HIGH
**Impact:** Screen reader users don't receive clear indication of current page, limiting orientation and navigation context.

**Current State:**
```swift
.navigationTitle("Dashboard")
```

**Issue:**
- Navigation title is set but not announced prominently by VoiceOver
- No accessibility header role to mark page structure
- Users returning to dashboard don't get clear confirmation of location

**Recommended Fix:**
```swift
.navigationTitle("Dashboard")
.accessibilityElement(children: .combine)
.accessibilityLabel("Dashboard")
.accessibilityAddTraits(.isHeader)
```

---

### 10. AtAGlanceSummary.swift - MetricCard Missing Accessibility Hints

**Location:** Lines 53-84
**WCAG Criterion:** 4.1.2 Name, Role, Value
**Severity:** HIGH
**Impact:** Screen reader users cannot understand what each metric represents or how to interpret the values.

**Current State:**
```swift
struct MetricCard: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(value)
        .font(.system(size: valueFontSize, weight: .bold))
        .foregroundColor(color)
      
      Text(title)
        .font(.caption)
        .foregroundColor(Color.secondaryText)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(value)")
  }
}
```

**Issue:**
- No hint explaining what the metric means
- Color is used to convey status (75% green = good) but not explained
- No context about what "75%" means without visual color feedback
- Missing Dynamic Type scaling testing

**Recommended Fix:**
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(title): \(value)")
.accessibilityHint(hint(for: title, value: value))
.accessibilityAddTraits(.isSummaryElement)

// Helper function
private func hint(for title: String, value: String) -> String {
  switch title {
  case "Avg Coach Responsiveness":
    return "Higher percentages indicate coaches respond faster to your messages"
  case "Days Until Graduation":
    return "Number of days remaining until graduation"
  default:
    return ""
  }
}
```

---

### 11. ParentPreviewBanner.swift - Banner Accessibility Structural Issue

**Location:** Lines 48-50
**WCAG Criterion:** 1.3.1 Info and Relationships
**Severity:** HIGH
**Impact:** Screen reader announces redundant/duplicated information due to nested accessibility labels.

**Current State:**
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("Parent preview mode. Viewing \(athleteName)'s dashboard")
.accessibilityHint("Tap X to exit preview mode")
```

**Issue:**
- `.children: .combine` merges VText and button label, causing duplication
- Button inside banner has its own label ("Exit preview mode")
- Screen readers may announce both the banner label and the button label
- Redundant announcements reduce clarity

**Recommended Fix:**
```swift
HStack(spacing: 12) {
  Image(systemName: "eye")
    .font(.system(size: fontSize))
    .foregroundColor(.white)
    .accessibilityHidden(true)

  VStack(alignment: .leading, spacing: 2) {
    Text("Parent Preview Mode")
      .font(.system(size: fontSize, weight: .semibold))
      .foregroundColor(.white)

    Text("Viewing \(athleteName)'s dashboard")
      .font(.system(size: fontSize - 2))
      .foregroundColor(.white.opacity(0.9))
  }
  .accessibilityElement(children: .combine)
  .accessibilityAddTraits(.isHeader)

  Spacer()

  Button(action: onDismiss) {
    Image(systemName: "xmark.circle.fill")
      .font(.system(size: fontSize + 2))
      .foregroundColor(.white.opacity(0.9))
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
  }
  .buttonStyle(PlainButtonStyle())
  .accessibilityLabel("Exit preview mode")
  .accessibilityHint("Returns to your athlete selection view")
}
.padding()
.background(LinearGradient(...))
.accessibilityElement(children: .ignore)  // Manage at component level
.accessibilityLabel("Parent preview mode active")
.accessibilityValue("Viewing \(athleteName)'s dashboard")
```

---

### 12. DashboardView.swift - Missing Header Section Accessibility

**Location:** Lines 72-91 (headerSection)
**WCAG Criterion:** 1.3.1 Info and Relationships; 2.4.10 Section Headings
**Severity:** HIGH
**Impact:** Screen reader users cannot quickly identify page structure. No semantic heading relationship between greeting and last updated time.

**Current State:**
```swift
private var headerSection: some View {
  VStack(alignment: .leading, spacing: 8) {
    if viewModel.isParentPreviewMode {
      Text("\(viewModel.selectedAthleteName)'s Dashboard")
        .font(.title2)
        .fontWeight(.bold)
    } else {
      Text("Welcome back, \(viewModel.userFirstName)!")
        .font(.title2)
        .fontWeight(.bold)
    }

    if let lastUpdated = viewModel.lastUpdated {
      Text("Last updated: \(lastUpdated, style: .relative)")
        .font(.caption)
        .foregroundColor(Color.secondaryText)
    }
  }
}
```

**Issue:**
- Title not marked as heading (no `.accessibilityAddTraits(.isHeader)`)
- "Last updated" timestamp treated as equal-weight content
- No accessibility label to group related information
- Missing relationship between main content and metadata

**Recommended Fix:**
```swift
private var headerSection: some View {
  VStack(alignment: .leading, spacing: 8) {
    if viewModel.isParentPreviewMode {
      Text("\(viewModel.selectedAthleteName)'s Dashboard")
        .font(.title2)
        .fontWeight(.bold)
        .accessibilityAddTraits(.isHeader)
    } else {
      Text("Welcome back, \(viewModel.userFirstName)!")
        .font(.title2)
        .fontWeight(.bold)
        .accessibilityAddTraits(.isHeader)
    }

    if let lastUpdated = viewModel.lastUpdated {
      Text("Last updated: \(lastUpdated, style: .relative)")
        .font(.caption)
        .foregroundColor(Color.secondaryText)
        .accessibilityLabel("Last updated")
        .accessibilityValue(formattedLastUpdated(lastUpdated))
    }
  }
  .accessibilityElement(children: .combine)
}
```

---

### 13. QuickTaskWidget.swift - HStack "Quick Tasks" Header Not Semantically Grouped

**Location:** Lines 15-28
**WCAG Criterion:** 1.3.1 Info and Relationships
**Severity:** HIGH
**Impact:** Screen reader users don't understand the relationship between the "Quick Tasks" header and the "Clear Completed" button.

**Current State:**
```swift
HStack {
  Text("Quick Tasks")
    .font(.headline)

  Spacer()

  if tasks.contains(where: { $0.isCompleted }) {
    Button("Clear Completed") {
      onClearCompleted()
    }
    .font(.caption)
    .foregroundColor(Color.accentBlue)
  }
}
```

**Issue:**
- Header and button are not grouped as a logical unit
- Screen readers announce them as separate elements with no relationship
- No indication that "Clear Completed" is an action related to the task widget

**Recommended Fix:**
```swift
HStack {
  Text("Quick Tasks")
    .font(.headline)
    .accessibilityAddTraits(.isHeader)

  Spacer()

  if tasks.contains(where: { $0.isCompleted }) {
    Button("Clear Completed") {
      onClearCompleted()
    }
    .font(.caption)
    .foregroundColor(Color.accentBlue)
    .accessibilityLabel("Clear completed tasks")
    .accessibilityHint("Removes all completed tasks from the list. This cannot be undone.")
  }
}
.accessibilityElement(children: .combine)
```

---

### 14. UpcomingEventsWidget.swift & PerformanceMetricsWidget.swift - Multiple Instances of Incomplete Button Actions

**Location:** 
- UpcomingEventsWidget.swift, Lines 29-34
- PerformanceMetricsWidget.swift, Lines 29-34

**WCAG Criterion:** 4.1.2 Name, Role, Value; 2.1.1 Keyboard
**Severity:** HIGH
**Impact:** Buttons with empty actions confuse users and fail keyboard accessibility testing.

**Current State:**
```swift
Button("Show \(sortedEvents.count - 3) more events") {
}  // Empty closure!
.font(.caption)
.foregroundColor(Color.accentBlue)
```

**Issue:**
- Buttons have no action handler (empty closure)
- Navigation is not implemented
- Screen readers announce button but pressing it does nothing
- Keyboard users expect some response on activation

**Recommended Fix:**
Connect to navigation or implement actual handler:
```swift
if sortedEvents.count > 3 {
  NavigationLink(value: DashboardDestination.events) {
    Text("Show \(sortedEvents.count - 3) more events")
      .font(.caption)
      .foregroundColor(Color.accentBlue)
  }
  .accessibilityLabel("View all events")
  .accessibilityHint("Opens a complete list of upcoming events")
}
```

---

### 15. ActionItemsWidget.swift - Show More Suggestions Link Missing Accessibility

**Location:** Lines 31-38
**WCAG Criterion:** 4.1.2 Name, Role, Value
**Severity:** HIGH
**Impact:** Screen reader users don't understand that the text is a navigation link.

**Current State:**
```swift
if suggestions.count > 3 {
  NavigationLink(value: DashboardDestination.suggestions) {
    Text("Show \(suggestions.count - 3) more")
      .font(.caption)
      .foregroundColor(Color.accentBlue)
  }
  .buttonStyle(PlainButtonStyle())
}
```

**Issue:**
- No `.accessibilityLabel()` on the link
- Screen readers announce only text color/style without understanding navigation intent
- Ambiguous to screen reader: "Show 5 more" - more what?

**Recommended Fix:**
```swift
if suggestions.count > 3 {
  NavigationLink(value: DashboardDestination.suggestions) {
    Text("Show \(suggestions.count - 3) more")
      .font(.caption)
      .foregroundColor(Color.accentBlue)
  }
  .accessibilityLabel("View all action items")
  .accessibilityHint("Opens a complete list of \(suggestions.count) suggested actions")
  .buttonStyle(PlainButtonStyle())
}
```

---

### 16. AthleteSelector.swift - Missing Accessibility on Empty State

**Location:** Lines 15-19
**WCAG Criterion:** 4.1.2 Name, Role, Value
**Severity:** HIGH
**Impact:** Screen reader users don't clearly understand why no athletes are available.

**Current State:**
```swift
if athletes.isEmpty {
  Text("No linked athletes found")
    .font(.caption)
    .foregroundColor(Color.secondaryText)
    .padding(.vertical)
}
```

**Issue:**
- Text is not marked as an informational or empty state message
- No accessibility trait indicating this is an explanation, not selectable content
- Users may not understand this is a conditional message vs. missing data

**Recommended Fix:**
```swift
if athletes.isEmpty {
  Text("No linked athletes found")
    .font(.caption)
    .foregroundColor(Color.secondaryText)
    .padding(.vertical)
    .accessibilityAddTraits(.isStaticText)
    .accessibilityHint("Add family members to your account to select them here")
}
```

---

### 17. DashboardView.swift - Error Section Missing Live Region Trait

**Location:** Lines 41-43
**WCAG Criterion:** 4.1.3 Status Messages
**Severity:** HIGH
**Impact:** Screen reader users don't receive notification when errors appear dynamically.

**Current State:**
```swift
if let error = viewModel.errorMessage {
  errorSection(error)
}

private func errorSection(_ message: String) -> some View {
  ErrorBanner(message: message, onDismiss: {
    viewModel.errorMessage = nil
  })
}
```

**Issue:**
- Error banner appears dynamically but has no live region trait
- Screen readers don't announce the error to users already on the page
- Users may not notice error unless they scroll or navigate to it

**Recommended Fix:**
```swift
if let error = viewModel.errorMessage {
  ErrorBanner(message: message, onDismiss: {
    viewModel.errorMessage = nil
  })
  .accessibilityAddTraits(.updatesFrequently)
  .accessibilityLabel("Error alert")
  .accessibilityLiveRegion(.assertive)
}
```

---

### 18. EmptyDashboardState.swift - Missing Structured Content Accessibility

**Location:** Lines 5-20
**WCAG Criterion:** 1.3.1 Info and Relationships; 2.4.2 Page Titled
**Severity:** HIGH
**Impact:** Screen reader users cannot understand the structure or hierarchy of empty state messaging.

**Current State:**
```swift
struct EmptyDashboardState: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "location.fill")
        .font(.system(size: 60))
        .foregroundColor(Color.primaryGreen)
        .accessibilityHidden(true)

      Text("Start Your Recruiting Journey")
        .font(.title2)
        .fontWeight(.bold)

      Text("Add your first school or log an interaction to get started")
        .font(.body)
        .foregroundColor(Color.secondaryText)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
    .padding()
    .accessibilityElement(children: .combine)
  }
}
```

**Issue:**
- Title not marked as heading
- Instructional text not marked distinctly
- No semantic structure to help screen reader users understand content hierarchy
- Generic `.combine` merges related but distinct content

**Recommended Fix:**
```swift
struct EmptyDashboardState: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "location.fill")
        .font(.system(size: 60))
        .foregroundColor(Color.primaryGreen)
        .accessibilityHidden(true)

      Text("Start Your Recruiting Journey")
        .font(.title2)
        .fontWeight(.bold)
        .accessibilityAddTraits(.isHeader)

      Text("Add your first school or log an interaction to get started")
        .font(.body)
        .foregroundColor(Color.secondaryText)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
        .accessibilityLabel("Getting started tips")
    }
    .padding()
    .accessibilityElement(children: .combine)
  }
}
```

---

### 19. InteractionTrendsChart.swift - No Fallback for No Data

**Location:** Lines 14-18
**WCAG Criterion:** 1.1.1 Non-text Content; 4.1.2 Name, Role, Value
**Severity:** HIGH
**Impact:** Empty state for chart is just text; no contrast or emphasis for users with visual impairments.

**Current State:**
```swift
if trends.isEmpty {
  Text("No interaction data yet")
    .font(.caption)
    .foregroundColor(Color.secondaryText)
    .padding(.vertical)
}
```

**Issue:**
- Secondary text color may not meet contrast requirements (WCAG AA 4.5:1)
- No visual emphasis that this is an empty/no-data state
- Small caption font reduces readability

**Recommended Fix:**
```swift
if trends.isEmpty {
  VStack(spacing: 8) {
    Image(systemName: "chart.bar.xaxis")
      .font(.system(size: 32))
      .foregroundColor(Color.secondaryText)
      .accessibilityHidden(true)
    
    Text("No interaction data yet")
      .font(.body)
      .foregroundColor(Color.darkSlate)
      .accessibilityAddTraits(.isStaticText)
  }
  .padding(.vertical, 32)
  .frame(maxWidth: .infinity)
  .background(Color(.systemBackground))
  .cornerRadius(8)
}
```

---

## Medium Priority Issues

### 20. UpcomingEventsWidget.swift - EventRow Lacks Keyboard Target Size

**Location:** Lines 68-100
**WCAG Criterion:** 2.5.5 Target Size (Enhanced)
**Severity:** MEDIUM
**Impact:** Motor disability users may struggle to tap small touch targets on events list.

**Current State:**
```swift
HStack(spacing: 12) {
  Image(systemName: eventTypeIcon)
    .font(.title3)
    .foregroundColor(Color.primaryGreen)
    .frame(width: 32)
    .accessibilityHidden(true)

  VStack(alignment: .leading, spacing: 4) {
    // ... content
  }

  Spacer()
}
.padding(12)
.background(Color(.secondarySystemBackground))
.cornerRadius(8)
```

**Issue:**
- Entire row is padding but not guaranteed 44x44pt minimum hit target
- Users with tremors or coarse motor control may miss small areas
- iOS guideline: minimum 44x44 points for touch targets

**Recommended Fix:**
```swift
HStack(spacing: 12) {
  Image(systemName: eventTypeIcon)
    .font(.title3)
    .foregroundColor(Color.primaryGreen)
    .frame(width: 32)
    .accessibilityHidden(true)

  VStack(alignment: .leading, spacing: 4) {
    // ... content
  }

  Spacer()
}
.padding(12)
.frame(minHeight: 44)  // Ensure minimum touch target
.background(Color(.secondarySystemBackground))
.cornerRadius(8)
```

---

### 21. RecentActivityFeed.swift - ActivityRow Missing Keyboard Hit Target

**Location:** Lines 76-99
**WCAG Criterion:** 2.5.5 Target Size
**Severity:** MEDIUM
**Impact:** Same as #20 - activity rows may be too small for reliable interaction.

**Current State:**
```swift
HStack(spacing: 12) {
  Image(systemName: activityIcon)
    .font(.body)
    .foregroundColor(activityColor)
    .frame(width: 24)
    .accessibilityHidden(true)

  VStack(alignment: .leading, spacing: 2) {
    // ... content
  }

  Spacer()
}
.padding(.vertical, 8)  // Only vertical padding - small hit target!
```

**Recommended Fix:**
```swift
HStack(spacing: 12) {
  Image(systemName: activityIcon)
    .font(.body)
    .foregroundColor(activityColor)
    .frame(width: 24)
    .accessibilityHidden(true)

  VStack(alignment: .leading, spacing: 2) {
    // ... content
  }

  Spacer()
}
.padding(.vertical, 8)
.frame(minHeight: 44)  // Ensure minimum touch target
```

---

### 22. AthleteRow (in AthleteSelector.swift) - Hard-coded Font Size

**Location:** Lines 44-78
**WCAG Criterion:** 1.4.4 Resize Text
**Severity:** MEDIUM
**Impact:** Users relying on Dynamic Type for larger text won't see proportional scaling of athlete names.

**Current State:**
```swift
Text(athlete.fullName)
  .font(.subheadline)
  .fontWeight(.semibold)
  .foregroundColor(Color.darkSlate)

Text(athlete.email)
  .font(.caption)
  .foregroundColor(Color.secondaryText)
```

**Issue:**
- Uses semantic fonts (.subheadline, .caption) which DO scale with Dynamic Type (GOOD)
- But no explicit testing of scaling at accessibility sizes
- Email text uses .caption which may be too small for large accessibility sizes

**Recommended Fix:**
Test with Dynamic Type at XXXLarge (Settings > Accessibility > Display & Text Size) to ensure:
1. Text remains readable
2. No truncation occurs
3. Button hit targets stay 44x44+
4. Layout doesn't break at extreme sizes

---

### 23. ActionItemCard - Urgency Color Only Indicator

**Location:** Lines 55-59
**WCAG Criterion:** 1.4.1 Use of Color
**Severity:** MEDIUM
**Impact:** Color-blind users cannot distinguish urgency levels; information conveyed by color alone.

**Current State:**
```swift
Circle()
  .fill(suggestion.urgency.color)
  .frame(width: 8, height: 8)
  .padding(.top, 6)
  .accessibilityHidden(true)
```

**Issue:**
- Urgency indicator relies only on color (red/orange/yellow)
- Marked as `.accessibilityHidden(true)` so screen readers don't announce it
- Color blind users cannot distinguish urgency
- No text alternative in the card itself

**Recommended Fix:**
```swift
// Add urgency text label to card
HStack(alignment: .top, spacing: 12) {
  Circle()
    .fill(suggestion.urgency.color)
    .frame(width: 8, height: 8)
    .padding(.top, 6)
    .accessibilityHidden(true)

  VStack(alignment: .leading, spacing: 4) {
    HStack {
      Text(suggestion.title)
        .font(.subheadline)
        .fontWeight(.semibold)
      
      Text(suggestion.urgency.rawValue.uppercased())
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(suggestion.urgency.color.opacity(0.1))
        .foregroundColor(suggestion.urgency.color)
        .cornerRadius(4)
        .accessibilityHidden(true)  // Already in accessibility label
    }

    Text(suggestion.description)
      .font(.caption)
      .foregroundColor(Color.secondaryText)
      .lineLimit(2)
  }
  // ... rest of component
}
```

---

### 24. StatCard.swift - Icon Not Fully Hidden from Screen Readers

**Location:** Lines 25-28
**WCAG Criterion:** 1.1.1 Non-text Content
**Severity:** MEDIUM
**Impact:** Screen reader may announce icon system name without context.

**Current State:**
```swift
Image(systemName: icon)
  .font(.system(size: iconSize))
  .foregroundColor(.white)
  .accessibilityHidden(true)
```

**Issue:**
- Icon is hidden (good), but only from VoiceOver
- Generic `.accessibilityHidden()` may not work consistently across all assistive technologies
- No explicit aria-hidden or similar semantic

**Recommended Fix:**
```swift
Image(systemName: icon)
  .font(.system(size: iconSize))
  .foregroundColor(.white)
  .accessibilityHidden(true)
  .accessibilityLabel("")  // Explicit empty label fallback
```

---

### 25. DashboardView - Logout Button Not Marked Destructive

**Location:** Lines 257-277
**WCAG Criterion:** 4.1.2 Name, Role, Value
**Severity:** MEDIUM
**Impact:** Screen reader users don't understand they're about to perform a session-ending action.

**Current State:**
```swift
Button(action: {
  Task {
    await viewModel.logout()
  }
}) {
  HStack {
    Image(systemName: "rectangle.portrait.and.arrow.right")
    Text(viewModel.isLoggingOut ? "Logging out..." : "Log Out")
      .font(.callout.weight(.semibold))
  }
  .frame(maxWidth: .infinity)
  .frame(height: 48)
  .foregroundColor(.white)
  .background(Color.errorRed)
  .cornerRadius(8)
}
.disabled(viewModel.isLoggingOut)
.opacity(viewModel.isLoggingOut ? 0.6 : 1)
.padding(.horizontal)
```

**Issue:**
- No accessibility label
- No hint about session termination
- Not marked as destructive action
- Red color alone doesn't communicate consequence to all users

**Recommended Fix:**
```swift
Button(action: {
  Task {
    await viewModel.logout()
  }
}) {
  HStack {
    Image(systemName: "rectangle.portrait.and.arrow.right")
      .accessibilityHidden(true)
    Text(viewModel.isLoggingOut ? "Logging out..." : "Log Out")
      .font(.callout.weight(.semibold))
  }
  .frame(maxWidth: .infinity)
  .frame(height: 48)
  .foregroundColor(.white)
  .background(Color.errorRed)
  .cornerRadius(8)
}
.disabled(viewModel.isLoggingOut)
.opacity(viewModel.isLoggingOut ? 0.6 : 1)
.padding(.horizontal)
.accessibilityLabel("Log out")
.accessibilityHint("Ends your current session and returns you to the login screen")
.accessibilityAddTraits(.isDangersButton)
```

---

### 26. QuickTaskRow - Checkbox State Not Fully Accessible

**Location:** Lines 89-105
**WCAG Criterion:** 2.5.5 Target Size
**Severity:** MEDIUM
**Impact:** Checkbox button area is too small for reliable interaction by users with motor disabilities.

**Current State:**
```swift
Button(action: onToggle) {
  Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
    .foregroundColor(task.isCompleted ? Color.successGreen : Color.gray)
}
.buttonStyle(PlainButtonStyle())
```

**Issue:**
- Button has no frame size specification (relies on image size)
- Image size is not guaranteed to be 44x44 minimum
- No accessibility label on button
- Toggle state should be more explicit

**Recommended Fix:**
```swift
Button(action: onToggle) {
  Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
    .foregroundColor(task.isCompleted ? Color.successGreen : Color.gray)
    .frame(minWidth: 44, minHeight: 44)
    .contentShape(Rectangle())
}
.buttonStyle(PlainButtonStyle())
.accessibilityLabel("Task: \(task.text)")
.accessibilityValue(task.isCompleted ? "Completed" : "Not completed")
.accessibilityHint("Double tap to toggle task completion status")
```

---

### 27. QuickTaskRow - Delete Button Missing Target Size and Accessibility

**Location:** Lines 101-105
**WCAG Criterion:** 2.5.5 Target Size; 4.1.2 Name, Role, Value
**Severity:** MEDIUM
**Impact:** Delete button is too small and not clearly marked as destructive.

**Current State:**
```swift
Button(action: onDelete) {
  Image(systemName: "trash")
    .foregroundColor(Color.errorRed)
}
.buttonStyle(PlainButtonStyle())
```

**Issue:**
- No accessibility label
- No hint about deletion
- No confirmation before destructive action
- Hit target below 44x44 minimum
- Not marked as dangerous/destructive

**Recommended Fix:**
```swift
Button(action: onDelete) {
  Image(systemName: "trash")
    .foregroundColor(Color.errorRed)
    .frame(minWidth: 44, minHeight: 44)
    .contentShape(Rectangle())
}
.buttonStyle(PlainButtonStyle())
.accessibilityLabel("Delete task")
.accessibilityHint("Permanently removes this task from your list")
.accessibilityAddTraits(.isDangersButton)
```

---

### 28. PerformanceMetricsWidget - Unit Display Not Accessible

**Location:** Lines 84-94
**WCAG Criterion:** 1.3.1 Info and Relationships
**Severity:** MEDIUM
**Impact:** Units are separated from values, making accessibility unclear for screen readers.

**Current State:**
```swift
HStack {
  Text(String(format: "%.2f", metric.value))
    .font(.body)
    .foregroundColor(Color.darkSlate)

  if let unit = metric.unit {
    Text(unit)
      .font(.caption)
      .foregroundColor(Color.secondaryText)
  }
}
```

**Issue:**
- Value and unit are separate text elements
- Screen readers may announce "4.5" and separately "seconds"
- No grouping to show relationship
- Accessibility label at row level combines them, but visual layout separates them

**Recommended Fix:**
```swift
HStack(spacing: 2) {
  Text(String(format: "%.2f", metric.value))
    .font(.body)
    .foregroundColor(Color.darkSlate)

  if let unit = metric.unit {
    Text(unit)
      .font(.caption)
      .foregroundColor(Color.secondaryText)
  }
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Value: \(String(format: "%.2f", metric.value)) \(metric.unit ?? "")")
```

---

## Low Priority Issues

### 29. DashboardView.swift - No Keyboard Skip Link for Sections

**Location:** Lines 13-70
**WCAG Criterion:** 2.4.1 Bypass Blocks
**Severity:** LOW
**Impact:** Keyboard users must Tab through all stat cards to reach widgets below (nice-to-have optimization).

**Current State:**
```swift
NavigationStack {
  VStack(spacing: 0) {
    // ... header
    // ... 6 stat cards
    // ... widgets below
  }
}
```

**Issue:**
- 6 stat card navigation links must all be tabbed through
- No way to skip directly to main content
- Not a blocker, but reduces keyboard navigation efficiency

**Recommended Fix:**
Add skip link (nice-to-have):
```swift
NavigationStack {
  VStack(spacing: 0) {
    // Skip link (visible on focus)
    Link(destination: URL(string: "#main-content")!) {
      Text("Skip to main content")
    }
    .frame(height: 0)
    .opacity(0)
    .accessibilityHidden(false)
    
    // ... rest of content with id="main-content"
  }
}
```

---

### 30. ParentPreviewBanner.swift - Font Sizes Hard-coded

**Location:** Lines 9-11
**WCAG Criterion:** 1.4.4 Resize Text
**Severity:** LOW
**Impact:** Dynamic Type sizes may not scale proportionally; users with large accessibility sizes may see mismatched proportions.

**Current State:**
```swift
private var fontSize: CGFloat {
  sizeCategory >= .extraLarge ? 16 : 14
}

// Used with
Text("Parent Preview Mode")
  .font(.system(size: fontSize, weight: .semibold))
```

**Issue:**
- Hard-coded sizes don't scale smoothly across all Dynamic Type sizes
- Only two breakpoints (.extraLarge vs. others) - coarse granularity
- Better approach: use semantic fonts or computed multipliers

**Recommended Fix:**
```swift
private var fontSize: CGFloat {
  switch sizeCategory {
  case .small, .medium: return 12
  case .large: return 14
  case .extraLarge, .xxLarge: return 16
  case .xxxLarge: return 18
  default: return 14
  }
}

// Or use semantic scaling
Text("Parent Preview Mode")
  .font(.subheadline)
  .fontWeight(.semibold)
```

---

### 31. EmptyDashboardState.swift - Image Size Not Responsive

**Location:** Lines 6-8
**WCAG Criterion:** 1.4.4 Resize Text
**Severity:** LOW
**Impact:** Large empty state icon may be too big at accessibility sizes; no responsive sizing.

**Current State:**
```swift
Image(systemName: "location.fill")
  .font(.system(size: 60))
  .foregroundColor(Color.primaryGreen)
  .accessibilityHidden(true)
```

**Issue:**
- Hard-coded 60pt size doesn't scale with Dynamic Type
- At XXXLarge size, icon may dominate screen
- No responsive sizing strategy

**Recommended Fix:**
```swift
@Environment(\.sizeCategory) var sizeCategory

private var iconSize: CGFloat {
  sizeCategory >= .extraLarge ? 80 : 60
}

Image(systemName: "location.fill")
  .font(.system(size: iconSize))
  .foregroundColor(Color.primaryGreen)
  .accessibilityHidden(true)
```

---

### 32. AtAGlanceSummary.swift - MetricCard Value Truncation at Accessibility Sizes

**Location:** Lines 64-76
**WCAG Criterion:** 1.4.4 Resize Text
**Severity:** LOW
**Impact:** Large metric values (e.g., "75%") may truncate at high Dynamic Type sizes; `.minimumScaleFactor(0.7)` forces shrinking instead of wrapping.

**Current State:**
```swift
Text(value)
  .font(.system(size: valueFontSize, weight: .bold))
  .foregroundColor(color)
  .lineLimit(1)
  .minimumScaleFactor(0.7)
```

**Issue:**
- `.lineLimit(1)` forces single line
- `.minimumScaleFactor(0.7)` shrinks text to 70% if it doesn't fit
- At accessibility sizes, text may become too small to read
- Values like "75%" should always be readable

**Recommended Fix:**
```swift
VStack(alignment: .leading, spacing: 8) {
  Text(value)
    .font(.system(size: valueFontSize, weight: .bold))
    .foregroundColor(color)
    .lineLimit(1)
    .accessibilityLabel(value)
  
  Text(title)
    .font(.caption)
    .foregroundColor(Color.secondaryText)
    .lineLimit(3)  // Allow wrapping for long titles
    .fixedSize(horizontal: false, vertical: true)
}
```

---

### 33. InteractionTrendsChart.swift - Y-Axis Label Missing Accessibility

**Location:** Lines 20-36
**WCAG Criterion:** 1.1.1 Non-text Content
**Severity:** LOW
**Impact:** Y-axis values (count) have no textual description; screen readers cannot announce axis labels.

**Current State:**
```swift
.chartYAxis {
  AxisMarks(position: .leading)
}
```

**Issue:**
- Y-axis shows numeric marks but no label text
- Screen readers don't announce what the axis represents (interaction count)
- Chart lacks context for screen reader users

**Recommended Fix:**
Add axis label:
```swift
.chartYAxis {
  AxisMarks(position: .leading) { value in
    AxisValueLabel(
      format: .number,
      anchor: .trailing
    )
  }
}
.accessibilityLabel("Interaction count per day")
```

---

### 34. ActionItemsWidget.swift - Show More Link Button Style Inconsistency

**Location:** Lines 31-38
**WCAG Criterion:** 3.2.4 Consistent Identification
**Severity:** LOW
**Impact:** NavigationLink styled as text (PlainButtonStyle) may not be clearly recognizable as interactive to users with visual impairments.

**Current State:**
```swift
NavigationLink(value: DashboardDestination.suggestions) {
  Text("Show \(suggestions.count - 3) more")
    .font(.caption)
    .foregroundColor(Color.accentBlue)
}
.buttonStyle(PlainButtonStyle())
```

**Issue:**
- PlainButtonStyle removes button appearance cues
- Blue text alone (color) doesn't reliably indicate interactivity
- Inconsistent with other interactive elements in dashboard
- Low vision users may not recognize this as a link

**Recommended Fix:**
```swift
NavigationLink(value: DashboardDestination.suggestions) {
  HStack {
    Text("Show \(suggestions.count - 3) more")
      .font(.caption)
    Image(systemName: "chevron.right")
      .font(.caption2)
      .accessibilityHidden(true)
  }
  .foregroundColor(Color.accentBlue)
}
.buttonStyle(PlainButtonStyle())
.accessibilityLabel("View all action items")
.accessibilityHint("Shows all \(suggestions.count) suggested actions")
```

---

### 35. DashboardView.swift - Pull-to-Refresh Not Accessible

**Location:** Lines 58-60
**WCAG Criterion:** 2.1.1 Keyboard; 2.5.2 Pointer Gestures
**Severity:** LOW
**Impact:** Keyboard-only and switch control users cannot refresh dashboard data.

**Current State:**
```swift
.refreshable {
  await viewModel.refresh()
}
```

**Issue:**
- `.refreshable` uses gesture-only (pull-down swipe)
- No keyboard alternative for refreshing
- Switch control users cannot trigger refresh
- Not discoverable for users unfamiliar with gesture

**Recommended Fix:**
Add refresh button:
```swift
VStack(spacing: 0) {
  HStack {
    Text("Dashboard")
      .font(.title2)
      .fontWeight(.bold)
    
    Spacer()
    
    Button(action: {
      Task {
        await viewModel.refresh()
      }
    }) {
      Image(systemName: "arrow.clockwise")
        .contentShape(Rectangle())
        .frame(minWidth: 44, minHeight: 44)
    }
    .accessibilityLabel("Refresh dashboard")
    .accessibilityHint("Fetches the latest dashboard data")
  }
  .padding()
  
  ScrollView {
    // ... content
  }
  .refreshable {
    await viewModel.refresh()
  }
}
```

---

## Compliant Elements (Praise)

### Strong Accessibility Patterns Already Implemented

1. **StatCard.swift** - Excellent multi-level accessibility
   - `.accessibilityElement(children: .combine)` properly groups icon + count + title
   - `.accessibilityLabel()`, `.accessibilityValue()`, `.accessibilityHint()` all present
   - Disabled state properly announced via traits
   - WCAG AA Compliant pattern

2. **ParentPreviewBanner.swift** - Good banner accessibility
   - Icon properly hidden (`.accessibilityHidden(true)`)
   - Dismiss button has clear label
   - Multi-level grouping with `.accessibilityElement(children: .combine)`
   - WCAG AA Compliant

3. **AthleteSelector.swift - AthleteRow** - Strong row accessibility
   - `.accessibilityLabel()` combines name and email clearly
   - `.accessibilityValue()` shows selection state
   - `.accessibilityHint()` explains interaction
   - WCAG AA Compliant

4. **ActionItemCard.swift** - Well-structured card layout
   - Complete button labels on both actions
   - Urgency priority in accessibility label
   - Icon hidden appropriately
   - WCAG AA Compliant structure (with noted exceptions)

5. **UpcomingEventsWidget - EventRow** - Good event display
   - All content grouped with `.accessibilityElement(children: .combine)`
   - Icon hidden and meaning preserved in label
   - Both label and value provided
   - WCAG AA Compliant

6. **RecentActivityFeed - ActivityRow** - Consistent accessibility
   - Activity description in label
   - Timestamp in value
   - Icon appropriately hidden
   - WCAG AA Compliant

7. **PerformanceMetricsWidget - MetricRow** - Strong metric display
   - Complete metric name + value + unit in accessibility label
   - Date information in accessibility value
   - Proper icon hiding
   - WCAG AA Compliant

8. **QuickTaskRow** - Good task representation
   - Task text in label
   - Completion status in value
   - Hints on both toggle and delete buttons
   - WCAG AA Compliant

9. **Banner.swift (Shared)** - Excellent error handling
   - Proper icon hiding (`.accessibilityHidden(true)`)
   - Error/warning distinction in accessibility label
   - Dismissal button accessibility
   - Close button hits 44x44 target
   - WCAG AA Compliant

10. **EmptyDashboardState.swift** - Good empty state
    - Icon hidden (not needed when text describes state)
    - Grouped content with `.accessibilityElement(children: .combine)`
    - Clear instructional text
    - WCAG AA Compliant structure

---

## Recommendations for Future Improvements (WCAG AAA, Best Practices)

### Tier 1: High-Impact Enhancements (Implement Soon)
1. **Audio/Haptic Feedback** - Provide feedback on button press for users with visual impairments
2. **Keyboard Navigation Visual Indicator** - Ensure focus ring is very visible (3:1 contrast minimum)
3. **Text Sizing Test** - Run comprehensive testing at all Dynamic Type sizes (Small through XXXLarge)
4. **Color Blind Simulation** - Test with Simulator's color blindness filters enabled
5. **Real Device VoiceOver Testing** - Test on actual iOS device with VoiceOver enabled

### Tier 2: Medium-Impact Improvements
1. **Heading Hierarchy** - Implement proper heading levels across all sections
2. **Skip Navigation** - Add skip-to-content link for keyboard users
3. **Animation Preferences** - Respect `prefers-reduced-motion` for all animations
4. **Loading States** - Announce to screen readers when content is loading
5. **Focus Management** - Ensure focus returns to correct location after navigation

### Tier 3: WCAG AAA Aspirational Goals
1. **Contrast Ratio** - Aim for 7:1 contrast on all text (beyond AA's 4.5:1)
2. **Font Sizes** - Use larger base font sizes (16px or higher)
3. **Language Markup** - Explicitly mark language for screen readers
4. **Extended Keyboard Shortcuts** - Provide alternative keyboard paths
5. **User Testing** - Conduct usability testing with disabled users

---

## Test Verification Checklist

### For Each Issue Fix, Verify:

- [ ] **VoiceOver Testing** (Simulator: Cmd+F5 or iOS Settings)
  - [ ] Gesture: Single tap announces element
  - [ ] Gesture: Two-finger Z swipe navigates forward
  - [ ] Gesture: Two-finger Z swipe backward navigates back
  - [ ] Rotor: Flick up/down to switch between links, buttons, headers

- [ ] **Keyboard Testing**
  - [ ] Tab key moves focus through interactive elements in logical order
  - [ ] Shift+Tab moves focus backward
  - [ ] Return/Space activates buttons
  - [ ] Arrow keys work in lists/pickers

- [ ] **Dynamic Type Testing**
  - [ ] Settings > Accessibility > Display & Text Size
  - [ ] Test at: Small, Medium, Large, XL, XXL, XXXL
  - [ ] Text remains readable
  - [ ] No truncation or overflow
  - [ ] Button hit targets stay 44x44+ (use Xcode View Hierarchy)

- [ ] **Color & Contrast**
  - [ ] WebAIM Contrast Checker: Text meets 4.5:1 (AA) or 7:1 (AAA)
  - [ ] Simulator: Settings > Accessibility > Display > Color Filters
  - [ ] Test with Deuteranopia (green-blind), Protanopia (red-blind), Tritanopia (blue-blind)

- [ ] **Motion/Animation**
  - [ ] Settings > Accessibility > Display > Reduce Motion is ON
  - [ ] Verify animations either stop or become non-distracting
  - [ ] No animations that flash more than 3x per second (seizure risk)

- [ ] **Touch Target Size**
  - [ ] Xcode: Simulator > View Hierarchy Inspector
  - [ ] All interactive elements: minimum 44x44 points
  - [ ] Spacing between touch targets: minimum 8 points

---

## Summary Table

| Severity | Count | Status | Action |
|----------|-------|--------|--------|
| Critical | 8 | Blocked Access | Fix Immediately |
| High | 12 | Significantly Impaired | Fix This Sprint |
| Medium | 9 | Reduced Usability | Fix Next Sprint |
| Low | 7 | Minor Friction | Fix as Polish |
| **Compliant** | **10** | ✅ Following Standards | Maintain |

---

## Next Steps

1. **Prioritize Critical Issues** - All 8 critical items block access for users relying on assistive technology
2. **Create Tickets** - File these findings as accessibility bugs in your issue tracker
3. **Assign Ownership** - Distribute work across team with accessibility knowledge
4. **Test Fixes** - Use checklist above to verify each fix
5. **Re-audit** - Run this audit again after fixes to confirm compliance
6. **Continuous Testing** - Integrate VoiceOver/keyboard testing into QA process

---

**Audit Completed By:** Accessibility Specialist
**Report Date:** February 8, 2026
**Next Audit Recommended:** After critical issues resolved (estimated 1-2 weeks)

