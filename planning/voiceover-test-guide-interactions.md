# VoiceOver Testing Guide: Interactions Feature
**Feature:** Add Interaction & Interaction Detail
**Purpose:** Manual QA script for VoiceOver accessibility validation
**Target:** WCAG 2.1 AA Compliance Verification
**Last Updated:** February 11, 2026

---

## Setup Instructions

### Enable VoiceOver on iOS Simulator
1. Launch iOS Simulator
2. Press **Cmd+F5** (toggles VoiceOver on/off)
3. Alternatively: **Settings → Accessibility → VoiceOver → On**

### VoiceOver Navigation Gestures
| Gesture | Action |
|---------|--------|
| **Swipe Right** | Move to next element |
| **Swipe Left** | Move to previous element |
| **Double-Tap** | Activate selected element |
| **Two-Finger Swipe Up** | Read from top |
| **Two-Finger Swipe Down** | Read from current position |
| **Three-Finger Swipe Left/Right** | Navigate between pages/screens |

---

## Test Suite 1: Add Interaction Form

### Test 1.1: Form Field Labels and Hints
**Objective:** Verify all form fields have proper accessibility labels and hints

**Steps:**
1. Navigate to Add Interaction screen (Dashboard → + button → Add Interaction)
2. Enable VoiceOver (Cmd+F5)
3. Swipe right from the top of the screen
4. Verify announcements for each field:

| Field | Expected Announcement | Pass/Fail |
|-------|----------------------|-----------|
| School Picker | "School picker. Required. Select the school for this interaction. Picker button." | ☐ |
| Coach Picker | "Coach picker. Optional. Select a coach or add a new one. Picker button." | ☐ |
| Type Picker | "Interaction type picker. Required. Select the type of interaction. Picker button." | ☐ |
| Direction Picker | "Direction picker. Select outbound (we initiated) or inbound (they initiated). Segmented control." | ☐ |
| Date Picker | "Date and time picker. When this interaction occurred. Date picker." | ☐ |
| Subject Field | "Subject field. Optional. Email subject, call topic, etc. Max 500 characters. Text field." | ☐ |
| Content Editor | "Content field. Optional. Details about the interaction. Max 10,000 characters. Text editor." | ☐ |
| Sentiment Picker | "Sentiment picker. Optional. Rate the tone of this interaction. Picker button." | ☐ |

**Pass Criteria:**
- ✅ All fields announce label
- ✅ Required fields mention "Required"
- ✅ Optional fields mention "Optional"
- ✅ Hints provide context for what to enter
- ✅ Field type announced (Picker, Text field, etc.)

---

### Test 1.2: Required Field Indicators
**Objective:** Verify required fields are clearly identified

**Steps:**
1. Swipe to "School" section header
2. Expected announcement: "School. Heading. *"
3. Swipe to "Type" section header
4. Expected announcement: "Type. Heading. *"
5. Swipe to "Direction" section header
6. Expected announcement: "Direction. Heading. *"

**Pass Criteria:**
- ✅ Asterisk (*) announced for required fields
- ✅ Section headers marked as headings

---

### Test 1.3: Submit Button States
**Objective:** Verify submit button announces enabled/disabled state clearly

**Test 1.3a: Disabled State**
**Steps:**
1. Navigate to empty Add Interaction form
2. Swipe to Submit button
3. Expected announcement: "Add Interaction. Cannot submit. Fill in required fields. Dimmed. Button."
4. Double-tap attempt
5. Expected behavior: No action (button disabled)

**Pass Criteria:**
- ✅ Button announces "Dimmed" trait
- ✅ Hint explains why disabled ("Fill in required fields")
- ✅ Double-tap does not submit

**Test 1.3b: Enabled State**
**Steps:**
1. Fill in required fields:
   - Select school
   - Select type
2. Swipe to Submit button
3. Expected announcement: "Add Interaction. Submit this interaction. Button."
4. Verify no "Dimmed" trait

**Pass Criteria:**
- ✅ No "Dimmed" trait announced
- ✅ Hint confirms action ("Submit this interaction")
- ✅ Double-tap submits form (verify with sighted assistance)

---

### Test 1.4: Interest Calibration Section
**Objective:** Verify conditional interest calibration section is accessible

**Precondition:**
1. Select School
2. Select Type: Email
3. Select Direction: Inbound
4. Select Sentiment: Positive
5. Wait for Interest Calibration section to appear

**Steps:**
1. Swipe to "Interest Calibration" section
2. Expected announcement: "Interest Calibration. Heading."
3. Swipe to first toggle
4. Expected announcement: "[Question text]. Yes/No. Toggle button."
   - Example: "Did the coach initiate contact without prompting? No. Toggle button."
5. Double-tap to toggle
6. Expected announcement: "Yes" (state changed)
7. Repeat for remaining toggles

**Pass Criteria:**
- ✅ Section header marked as heading
- ✅ Question text announced verbatim
- ✅ Current state announced ("Yes" or "No")
- ✅ State changes announced after toggle
- ✅ All toggles accessible in logical order

---

### Test 1.5: Character Count Warnings
**Objective:** Verify character count warnings are accessible

**Steps:**
1. Swipe to Subject field
2. Type 451 characters (triggers character count at 450+)
3. Swipe forward after typing
4. Expected announcement: "[Current count] of 500 characters. Caption."
5. Repeat for Content field (9501+ characters)

**Pass Criteria:**
- ✅ Character count announced when nearing limit
- ✅ Count updates dynamically
- ✅ Warning tone appropriate (not alarming unless near limit)

---

### Test 1.6: Cancel Button
**Objective:** Verify cancel button is accessible

**Steps:**
1. Swipe to Cancel button (top-left navigation bar)
2. Expected announcement: "Cancel. Button."
3. Double-tap
4. Expected behavior: Dismiss Add Interaction sheet

**Pass Criteria:**
- ✅ Button labeled clearly
- ✅ Double-tap dismisses sheet

---

## Test Suite 2: Interaction Detail

### Test 2.1: Content Hierarchy
**Objective:** Verify proper heading hierarchy for VoiceOver navigation

**Steps:**
1. Navigate to Interaction Detail screen
2. Swipe right from top
3. Verify heading structure:

| Element | Expected Announcement | Pass/Fail |
|---------|----------------------|-----------|
| Subject | "[Subject text]. Heading." | ☐ |
| Date | "Occurred at [date]. Secondary text." | ☐ |
| Type Badge | "[Type] interaction. Badge." | ☐ |
| Direction Badge | "[Direction] direction. Badge." | ☐ |
| Sentiment Badge | "Sentiment: [sentiment]. Badge." (if present) | ☐ |
| Content Header | "Content. Heading." | ☐ |
| Content Text | "[Content text]. Selectable text." | ☐ |
| Details Header | "Details. Heading." | ☐ |

**Pass Criteria:**
- ✅ Subject marked as heading
- ✅ Section headers (Content, Details) marked as headings
- ✅ Badges announce context
- ✅ Decorative icons not announced

---

### Test 2.2: Badge Accessibility
**Objective:** Verify badges provide contextual information

**Steps:**
1. Swipe to first badge (Type)
2. Expected announcement: "[Type name] interaction."
   - Example: "Email interaction."
3. Swipe to second badge (Direction)
4. Expected announcement: "[Direction] direction."
   - Example: "Outbound direction."
5. Swipe to third badge (Sentiment, if present)
6. Expected announcement: "Sentiment: [sentiment name]."
   - Example: "Sentiment: Positive."

**Pass Criteria:**
- ✅ Type badge includes "interaction" context
- ✅ Direction badge includes "direction" context
- ✅ Sentiment badge includes "Sentiment:" prefix
- ✅ Icon within badge not announced separately

---

### Test 2.3: Detail Grid Navigation
**Objective:** Verify detail grid items announce correctly

**Steps:**
1. Swipe to Details section
2. Verify grid item announcements:

| Grid Item | Expected Announcement | Pass/Fail |
|-----------|----------------------|-----------|
| School (tappable) | "School: [School name], tap to view details. Button." | ☐ |
| Coach (tappable) | "Coach: [Coach name], tap to view details. Button." | ☐ |
| Event (not tappable) | "Event: —" | ☐ |
| Logged By (not tappable) | "Logged By: [User name]" | ☐ |

**Pass Criteria:**
- ✅ Tappable items have "Button" trait
- ✅ Tappable items include "tap to view details" hint
- ✅ Non-tappable items do NOT have button trait
- ✅ Icon decorations not announced separately

---

### Test 2.4: Actions Menu
**Objective:** Verify actions menu (Export, Delete) is accessible

**Steps:**
1. Swipe to top-right navigation bar
2. Expected announcement: "Interaction actions menu. Button."
3. Double-tap to open menu
4. Swipe through menu items:
   - "Export. Share." (if export enabled)
   - "Delete. Button. Destructive action." (if delete enabled)

**Pass Criteria:**
- ✅ Menu button labeled clearly
- ✅ Menu items announce action name
- ✅ Delete marked as "Destructive action"

---

### Test 2.5: Delete Confirmation Dialog
**Objective:** Verify delete confirmation is accessible

**Steps:**
1. Activate Delete from actions menu
2. Expected announcement: "Delete Interaction. Confirmation dialog."
3. Swipe to message text
4. Expected announcement: "Are you sure you want to delete this interaction? This action cannot be undone."
5. Swipe to Delete button
6. Expected announcement: "Delete. Destructive. Button."
7. Swipe to Cancel button
8. Expected announcement: "Cancel. Button."

**Pass Criteria:**
- ✅ Dialog announces as confirmation
- ✅ Message text announced
- ✅ Delete button marked "Destructive"
- ✅ Cancel button present and labeled

---

### Test 2.6: Metadata Section
**Objective:** Verify metadata is accessible

**Steps:**
1. Swipe to bottom of detail view
2. Expected announcement: "Created: [date]. Caption."
3. If attachments present:
4. Expected announcement: "Attachments: [count]. Caption."

**Pass Criteria:**
- ✅ Created date announced
- ✅ Attachment count announced (if present)
- ✅ Metadata marked as "Caption" (secondary info)

---

## Test Suite 3: Dynamic Type Scaling

### Test 3.1: Large Text Scaling (200%)
**Objective:** Verify content scales to 200% without truncation

**Setup:**
1. Settings → Accessibility → Display & Text Size → Larger Text
2. Drag slider to 200% (middle-large)

**Steps:**
1. Navigate to Add Interaction
2. Visually verify:
   - All labels visible
   - No text truncation (no "...")
   - Form remains scrollable
   - Submit button accessible
3. Navigate to Interaction Detail
4. Visually verify:
   - Subject heading visible
   - All badge text readable
   - Content section doesn't overflow
   - Grid items remain readable

**Pass Criteria:**
- ✅ All text scales proportionally
- ✅ No truncation at 200%
- ✅ Layout adapts (stacks if needed)
- ✅ No horizontal scrolling required

---

### Test 3.2: Maximum Text Scaling (310%)
**Objective:** Verify robustness at maximum accessibility size

**Setup:**
1. Settings → Accessibility → Display & Text Size → Larger Text
2. Drag slider to **maximum** (310%)

**Steps:**
1. Navigate to Add Interaction
2. Visually verify:
   - Form fields stack vertically
   - All text visible (check pickers)
   - Submit button remains on-screen
3. Scroll through entire form
4. Navigate to Interaction Detail
5. Visually verify:
   - Subject heading doesn't overflow
   - Badges may wrap to multiple lines (acceptable)
   - Detail grid items remain distinct

**Pass Criteria:**
- ✅ All content accessible (may require scrolling)
- ✅ No complete text cut-off
- ✅ Interaction remains functional
- ✅ Critical actions (Submit, Cancel) visible

---

## Test Suite 4: Touch Target Verification

### Test 4.1: Minimum Touch Target Size
**Objective:** Verify all interactive elements meet 44pt minimum

**Setup:**
1. Disable VoiceOver for visual inspection
2. Enable Accessibility Inspector (Xcode → Developer Tools → Accessibility Inspector)

**Steps:**
1. Navigate to Add Interaction
2. Use Accessibility Inspector to measure:
   - Cancel button: Height ≥ 44pt
   - Submit button: Height ≥ 44pt
   - Picker tap areas: Height ≥ 44pt
   - Toggle switches: Height ≥ 44pt
3. Navigate to Interaction Detail
4. Measure:
   - Actions menu button: Height ≥ 44pt
   - School grid item: Height ≥ 44pt
   - Coach grid item: Height ≥ 44pt

**Pass Criteria:**
- ✅ All interactive elements ≥ 44pt height
- ✅ All interactive elements ≥ 44pt width
- ✅ Touch areas do not overlap

---

## Test Suite 5: Keyboard Navigation

### Test 5.1: Keyboard Dismissal
**Objective:** Verify keyboard dismisses correctly

**Steps:**
1. Navigate to Add Interaction
2. Tap Subject field (keyboard appears)
3. Scroll down in form
4. Expected behavior: Keyboard dismisses interactively

**Pass Criteria:**
- ✅ Keyboard dismisses on scroll
- ✅ Keyboard can be re-summoned by tapping field

---

## Test Suite 6: Color Contrast (Visual Inspection)

### Test 6.1: Light Mode Contrast
**Objective:** Verify text meets 4.5:1 contrast ratio in light mode

**Setup:**
1. Settings → Display & Brightness → Light Mode
2. Use Accessibility Inspector Color Contrast tool

**Elements to Check:**
| Element | Expected Ratio | Pass/Fail |
|---------|----------------|-----------|
| Form labels (primary) | ≥ 7:1 | ☐ |
| Secondary text | ≥ 4.5:1 | ☐ |
| Badge text | ≥ 4.5:1 | ☐ |
| Button text (white on blue) | ≥ 7:1 | ☐ |
| Error text | ≥ 4.5:1 | ☐ |

---

### Test 6.2: Dark Mode Contrast
**Objective:** Verify text meets 4.5:1 contrast ratio in dark mode

**Setup:**
1. Settings → Display & Brightness → Dark Mode
2. Use Accessibility Inspector Color Contrast tool

**Elements to Check:**
| Element | Expected Ratio | Pass/Fail |
|---------|----------------|-----------|
| Form labels (primary) | ≥ 7:1 | ☐ |
| Secondary text | ≥ 4.5:1 | ☐ |
| Badge text | ≥ 4.5:1 | ☐ |
| Button text | ≥ 7:1 | ☐ |
| Error text | ≥ 4.5:1 | ☐ |

---

## Test Suite 7: Error Handling

### Test 7.1: Form Validation Errors
**Objective:** Verify validation errors are accessible

**Steps:**
1. Leave required fields empty
2. Attempt to submit
3. Expected behavior: Submit button disabled (no error)
4. Fill in School and Type
5. Trigger a server error (mock scenario)
6. Expected announcement: "Error. [Error message]. OK. Button."

**Pass Criteria:**
- ✅ Error alert announces clearly
- ✅ Error message text readable
- ✅ OK button accessible

---

### Test 7.2: Loading States
**Objective:** Verify loading states announce properly

**Steps:**
1. Navigate to Add Interaction (triggers form data load)
2. If loading state visible:
3. Expected announcement: "Loading form data... Progress indicator."

**Pass Criteria:**
- ✅ Loading message announced
- ✅ Progress indicator identified

---

## Test Results Summary

### Date Tested: _______________
### Tester Name: _______________
### Device/Simulator: _______________

| Test Suite | Pass | Fail | Notes |
|------------|------|------|-------|
| 1.1 Form Field Labels | ☐ | ☐ | |
| 1.2 Required Field Indicators | ☐ | ☐ | |
| 1.3 Submit Button States | ☐ | ☐ | |
| 1.4 Interest Calibration | ☐ | ☐ | |
| 1.5 Character Count Warnings | ☐ | ☐ | |
| 1.6 Cancel Button | ☐ | ☐ | |
| 2.1 Content Hierarchy | ☐ | ☐ | |
| 2.2 Badge Accessibility | ☐ | ☐ | |
| 2.3 Detail Grid Navigation | ☐ | ☐ | |
| 2.4 Actions Menu | ☐ | ☐ | |
| 2.5 Delete Confirmation | ☐ | ☐ | |
| 2.6 Metadata Section | ☐ | ☐ | |
| 3.1 Large Text Scaling (200%) | ☐ | ☐ | |
| 3.2 Maximum Text Scaling (310%) | ☐ | ☐ | |
| 4.1 Touch Target Size | ☐ | ☐ | |
| 5.1 Keyboard Dismissal | ☐ | ☐ | |
| 6.1 Light Mode Contrast | ☐ | ☐ | |
| 6.2 Dark Mode Contrast | ☐ | ☐ | |
| 7.1 Form Validation Errors | ☐ | ☐ | |
| 7.2 Loading States | ☐ | ☐ | |

**Overall Result:** ☐ PASS ☐ FAIL

**Issues Found:**
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

**Recommendations:**
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

---

## Appendix: VoiceOver Rotor

### What is the Rotor?
The Rotor is a VoiceOver feature that allows quick navigation by element type.

### How to Use:
1. **Activate Rotor:** Two-finger rotate gesture (like turning a dial)
2. **Select Category:** Swipe up/down to choose (Headings, Links, Form Controls, etc.)
3. **Navigate:** Swipe up/down to jump between elements of that type

### Useful Rotor Categories for Testing:
- **Headings:** Jump between section headers
- **Form Controls:** Jump between pickers, text fields, buttons
- **Links:** Jump between navigation links
- **Buttons:** Jump between actionable elements

---

## Quick Reference: Expected vs. Actual

### Add Interaction - Full VoiceOver Flow
**Expected reading order (top to bottom):**
1. "Add Interaction. Heading. Navigation bar."
2. "Cancel. Button."
3. "School picker. Required..."
4. "Coach picker. Optional..."
5. "Interaction type picker. Required..."
6. "Direction picker..."
7. "Date and time picker..."
8. "Subject field. Optional..."
9. "Content field. Optional..."
10. "Sentiment picker. Optional..."
11. [If triggered] "Interest Calibration. Heading."
12. [If triggered] "[Question 1]. No. Toggle button."
13. [If triggered] "[Question 2]. No. Toggle button."
14. [If triggered] "[Question 3]. No. Toggle button."
15. [If triggered] "[Question 4]. No. Toggle button."
16. [If triggered] "[Question 5]. No. Toggle button."
17. [If triggered] "Interest level: [level]. [description]."
18. "Add Interaction. Cannot submit... Button."
19. "Cancel. Button."

---

## Troubleshooting

### Issue: VoiceOver not announcing label
**Solution:** Verify `.accessibilityLabel()` is set in code

### Issue: Icon announced separately
**Solution:** Verify `.accessibilityHidden(true)` on decorative icons

### Issue: Button not activating
**Solution:** Verify element has `.accessibilityAddTraits(.isButton)`

### Issue: Text too small at 310%
**Solution:** Verify semantic fonts (`.body`, `.caption`) used instead of `.system(size:)`

---

**Document Version:** 1.0
**Last Updated:** February 11, 2026
**Next Review:** After any UI changes to Interactions feature
