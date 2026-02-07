# Dynamic Type Support Implementation Plan

**Status:** IN PROGRESS
**Session:** 5 (Fresh Context) - Dynamic Type Support Phase
**Target Completion:** High priority optional enhancement
**Date Started:** February 6, 2026

---

## 📋 Overview

Implement Dynamic Type support for all authentication screens to enable text scaling from small to extra-large sizes, maintaining accessibility and usability across all text size preferences.

**Success Criteria:**
- All layouts remain responsive at small (0.7x) through extra-large (1.5x) text scales
- Button hit targets remain ≥ 44x44 points at all text sizes
- No layout breaking or text clipping at any size
- All Phase 1 & 2 accessibility features remain functional
- 100% test coverage for Dynamic Type scenarios
- Zero regressions in existing functionality

---

## 🎯 Tasks (Sequential Coordination)

### PARALLEL Tasks (Can Run Simultaneously)

#### Task A: Layout Analysis
**Objective:** Identify current layout structure and Dynamic Type vulnerabilities
**Owner:** Will be assigned to analysis subagent
**Scope:**
- Read all auth view files (LoginView, SignupView, EmailVerificationView)
- Read all auth component files (all components in Components folder)
- Read Landing and Dashboard views
- Document fixed vs. flexible spacing
- Identify hard-coded font sizes
- Identify potential text clipping issues
- Map component hierarchy and dependencies

**Deliverables:**
- Report of all fixed spacing/sizing
- List of components needing adaptation
- Priority ranking (critical → nice-to-have)

#### Task B: Dynamic Type Testing
**Objective:** Test current behavior at various text size scales
**Owner:** Will be assigned to testing subagent
**Scope:**
- Build app with Dynamic Type enabled
- Test at sizes: Small (0.7x), Normal (1.0x), Large (1.2x), XL (1.5x)
- Screenshot each screen at each size
- Document layout issues, clipping, hit target problems
- Verify current accessibility features still work

**Deliverables:**
- Test results summary by screen
- Screenshots showing issues
- Video evidence of any layout breaking

---

### SEQUENTIAL Tasks (Dependent on A+B)

#### Task C: Fix Planning
**Objective:** Create detailed fix plan based on analysis results
**Owner:** Assigned after A+B complete
**Input:** Results from Task A & B
**Scope:**
- Prioritize fixes (critical first)
- Determine which components need `.lineLimit()`, `.minimumScaleFactor()`, etc.
- Plan layout adjustments
- Identify test coverage needed
- Create fix checklist

**Deliverables:**
- Detailed fix plan document
- Component-by-component adaptation strategy

#### Task D: Implement Fixes
**Objective:** Apply Dynamic Type adaptations to all views/components
**Owner:** Assigned after C complete
**Scope:**
- LoginView layout adjustments
- SignupView layout adjustments
- EmailVerificationView layout adjustments
- All component layout adjustments (LoginFormField, ErrorBanner, etc.)
- Font size adaptations where needed
- Spacing/padding adaptations
- Verify no breaking changes to existing code

**Deliverables:**
- All modified files committed to feature branch
- Build succeeds (0 errors, 0 warnings)

#### Task E: Write Dynamic Type Tests
**Objective:** Create comprehensive test suite for Dynamic Type support
**Owner:** Assigned after D complete
**Scope:**
- Create test files for each view/component
- Test layout stability at multiple text sizes
- Test button hit targets ≥ 44x44
- Test for text clipping
- Test accessibility features still work
- Write ~30-40 new tests

**Deliverables:**
- New test files with 100% passing tests
- Tests cover small through XL sizes

#### Task F: Verification & Regression Testing
**Objective:** Comprehensive verification of Dynamic Type support
**Owner:** Assigned after E complete
**Scope:**
- Run full test suite (should be 156+ passing)
- Manual testing at all text sizes (both simulator and real device if available)
- Verify Phase 1 & 2 accessibility features still work
- Performance verification (no regressions)
- Build verification (clean, 0 errors/warnings)
- Document any edge cases or known limitations

**Deliverables:**
- Full test results
- Build output (clean)
- Manual testing results
- Final sign-off ready for code review

---

## 📁 Files to Modify

### Views (Need Analysis)
- `Features/Auth/Views/LoginView.swift`
- `Features/Auth/Views/SignupView.swift`
- `Features/Auth/Views/EmailVerificationView.swift`
- `Features/Landing/Views/LandingView.swift`
- `Features/Dashboard/Views/DashboardView.swift`

### Components (Need Analysis)
- `Features/Auth/Components/LoginFormField.swift`
- `Features/Auth/Components/ErrorBanner.swift`
- `Features/Auth/Components/TimeoutBanner.swift`
- `Features/Auth/Components/InfoBanner.swift`
- `Features/Auth/Components/RoleSelectionCard.swift`
- `Features/Auth/Components/TermsCheckbox.swift`
- `Features/Auth/Components/PasswordStrengthIndicator.swift`
- `Features/Auth/Components/VerificationStatusIcon.swift`

### Tests to Create
- `TheRecruitingCompassTests/DynamicType/LoginViewDynamicTypeTests.swift`
- `TheRecruitingCompassTests/DynamicType/SignupViewDynamicTypeTests.swift`
- `TheRecruitingCompassTests/DynamicType/EmailVerificationViewDynamicTypeTests.swift`
- `TheRecruitingCompassTests/DynamicType/LoginFormFieldDynamicTypeTests.swift`
- `TheRecruitingCompassTests/DynamicType/ComponentsDynamicTypeTests.swift`

---

## 🔍 Key Questions to Answer During Analysis

1. **Fixed vs Flexible:** Which spacing/font sizes are hard-coded vs. responsive?
2. **Layout Stability:** Which screens break at extreme text sizes?
3. **Text Clipping:** Where does text get cut off or overflow?
4. **Hit Targets:** Any buttons that shrink below 44x44 at small text sizes?
5. **Accessibility:** Do Phase 1 & 2 features still work with text scaling?
6. **Priority:** What's the minimal set of fixes for MVP?

---

## 🚀 Implementation Approach

### SwiftUI Dynamic Type Patterns

**Pattern 1: Flexible Font Sizes**
```swift
Text("Label")
  .font(.system(.body, design: .default))  // Responsive to text size
  // NOT: .font(.system(size: 16)) - hard-coded!
```

**Pattern 2: Adaptive Spacing**
```swift
VStack(spacing: .dynamicSpacing) {
  // Use .small, .medium, .large instead of hard-coded values
}
```

**Pattern 3: Text Truncation**
```swift
Text("Long text")
  .lineLimit(2)  // Prevent excessive wrapping
  .minimumScaleFactor(0.8)  // Scale down before wrapping
```

**Pattern 4: Layout Adaptation**
```swift
VStack {
  if sizeCategory > .large {
    // Switch to single-column layout for large text
  } else {
    // Use multi-column layout for normal text
  }
}
.environment(\.sizeCategory, $0)  // For testing
```

**Pattern 5: Button Hit Targets**
```swift
Button(action: {}) {
  Text("Action")
}
.frame(minHeight: 44)  // Ensure minimum hit target
```

---

## ✅ Verification Checklist

- [ ] Task A: Layout analysis complete
- [ ] Task B: Dynamic Type testing complete
- [ ] Task C: Fix planning complete
- [ ] Task D: All layouts adapted (build succeeds)
- [ ] Task E: 30-40 tests written and passing
- [ ] Task F: Full regression testing passing
- [ ] Phase 1 & 2 accessibility features verified
- [ ] 156+ tests passing (126 existing + 30+ new)
- [ ] Build clean (0 errors, 0 warnings)
- [ ] Ready for code review

---

## 📊 Expected Outcomes

**By Task Completion:**
- Layouts responsive at 0.7x - 1.5x text scales
- All button hit targets ≥ 44x44
- No text clipping at any size
- 156+ tests passing
- Zero regressions
- Production-ready Dynamic Type support

**Metrics:**
- Files Modified: 8-10 (views + components)
- Tests Created: ~40
- Test Coverage: 100% of modified areas
- Build Time: ~60 seconds
- Test Suite Run: ~3 minutes

---

## 🎬 Next Steps

1. **Dispatch Task A & B in Parallel:** Layout analysis + Dynamic Type testing
2. **Wait for results:** Analyze findings
3. **Dispatch Task C:** Fix planning based on results
4. **Dispatch Task D:** Implementation
5. **Dispatch Task E:** Test writing
6. **Dispatch Task F:** Final verification
7. **Code Review:** Request review when complete
8. **Merge:** Integrate to main after review

---

## 📚 References

- **MEMORY.md:** Project status, architecture, previous phases
- **HANDOFF_SESSION_4.md:** Phase 2 accessibility details
- **LOGIN_SPEC_COMPLETION_SUMMARY.md:** Feature spec and requirements
- **Apple Human Interface Guidelines:** Dynamic Type best practices
- **SwiftUI Documentation:** Environment modifiers, font sizing

---

**Status:** Ready to dispatch Task A & B subagents
