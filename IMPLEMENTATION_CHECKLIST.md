# DETAILED IMPLEMENTATION CHECKLIST - DYNAMIC TYPE SUPPORT

**Status:** READY FOR IMPLEMENTATION
**Date:** February 6, 2026
**Estimated Duration:** 2-3 hours total (broken into phases)

---

## SECTION 1: FONT SIZE MAPPING REFERENCE

### Standard SwiftUI Dynamic Type Fonts (Semantic)
These automatically scale with system settings:

```swift
// Use these instead of hard-coded sizes:
.font(.largeTitle)        // ~34pt, scales to ~44pt at XXL
.font(.title)             // ~28pt, scales to ~34pt at XXL
.font(.title2)            // ~22pt, scales to ~26pt at XXL
.font(.title3)            // ~20pt, scales to ~23pt at XXL
.font(.headline)          // ~17pt, scales to ~22pt at XXL
.font(.body)              // ~17pt, scales to ~22pt at XXL
.font(.callout)           // ~16pt, scales to ~20pt at XXL
.font(.subheadline)       // ~15pt, scales to ~19pt at XXL
.font(.footnote)          // ~13pt, scales to ~16pt at XXL
.font(.caption)           // ~12pt, scales to ~15pt at XXL
.font(.caption2)          // ~11pt, scales to ~14pt at XXL
```

### Hard-Coded to Semantic Mapping
- **Size 11-12** → `.caption` or `.caption2`
- **Size 14** → `.footnote` or `.callout`
- **Size 16** → `.callout` or `.headline`
- **Size 20** → `.title3`
- **Size 24** → `.title2`
- **Size 28** → `.title`
- **Size 48+** (icons) → Use with `@Environment(\.sizeCategory)` scaling

---

## SECTION 2: BUTTON HIT TARGET FIX PATTERN

```swift
// Pattern: All interactive elements must be ≥44x44 points
Button(action: { action() }) {
  Text("Label")
    .font(.footnote)  // Semantic font
}
.frame(minHeight: 44)  // Minimum hit target
.contentShape(Rectangle())  // Expand touch area
```

---

## SECTION 3: ICON SCALING PATTERN

```swift
@Environment(\.sizeCategory) var sizeCategory

var scaledIconSize: CGFloat {
  switch sizeCategory {
  case .small, .medium, .large: return 48
  case .xLarge, .xxLarge: return 52
  case .xxxLarge: return 56
  default: return 48
  }
}

Image(systemName: "icon")
  .font(.system(size: scaledIconSize))
```

---

## PHASE 1: CRITICAL VIEWS

### FILE 1: LoginView.swift

**10 font size fixes + 2 button hit target fixes**

#### Fix 1.1: Back Button Text (Lines 30, 33)
```swift
// BEFORE:
.font(.system(size: 14, weight: .semibold))

// AFTER:
.font(.footnote.weight(.semibold))
```

#### Fix 1.2: Compass Icon (Line 47)
```swift
// BEFORE:
.font(.system(size: 48))

// AFTER:
@Environment(\.sizeCategory) var sizeCategory
var compassSize: CGFloat {
  sizeCategory >= .xLarge ? 52 : 48
}
// Then: .font(.system(size: 48)).scaleEffect(sizeCategory >= .xLarge ? 1.08 : 1.0)
```

#### Fix 1.3: Remember Me Text (Line 112)
```swift
// BEFORE:
.font(.system(size: 14, weight: .regular))

// AFTER:
.font(.footnote)
```

#### Fix 1.4: Forgot Password Link (Line 125) - **BUTTON HIT TARGET FIX**
```swift
// BEFORE:
.font(.system(size: 14, weight: .regular))
// No frame - may be < 44pt height

// AFTER:
.font(.footnote)
.frame(minHeight: 44)  // Ensure 44x44 minimum
```

#### Fix 1.5: Sign In Button Text (Line 139)
```swift
// BEFORE:
.font(.system(size: 16, weight: .semibold))

// AFTER:
.font(.callout.weight(.semibold))
```

#### Fix 1.6: Divider Text (Line 173)
```swift
// BEFORE:
.font(.system(size: 14, weight: .regular))

// AFTER:
.font(.footnote)
```

#### Fix 1.7: Account Links (Lines 184, 190)
```swift
// BEFORE (Line 184):
.font(.system(size: 14, weight: .regular))

// AFTER:
.font(.footnote)

// BEFORE (Line 190):
.font(.system(size: 14, weight: .semibold))

// AFTER:
.font(.footnote.weight(.semibold))
```

#### Fix 1.8: Create Account Arrow (Line 192) - **BUTTON HIT TARGET FIX**
```swift
// BEFORE:
.font(.system(size: 12, weight: .semibold))
// Part of navigation link without explicit hit target

// AFTER:
.font(.caption.weight(.semibold))
.frame(minHeight: 44)  // Ensure link is tappable
```

**Status:** ✅ Ready to implement

---

### FILE 2: SignupView.swift

**11 font size fixes + 1 critical button hit target fix**

#### Fix 2.1: Back Button (Lines 25, 28)
```swift
// BEFORE:
.font(.system(size: 14, weight: .semibold))

// AFTER:
.font(.footnote.weight(.semibold))
```

#### Fix 2.2: Compass Icon (Line 64)
```swift
// BEFORE:
.font(.system(size: 48))

// AFTER:
@Environment(\.sizeCategory) var sizeCategory
// Scale effect: sizeCategory >= .xLarge ? 1.08 : 1.0
```

#### Fix 2.3: Headline (Line 71) - **CRITICAL**
```swift
// BEFORE:
.font(.system(size: 20, weight: .semibold))

// AFTER:
.font(.title3.weight(.semibold))
```

#### Fix 2.4: Subtitle (Line 75)
```swift
// BEFORE:
.font(.system(size: 14, weight: .regular))

// AFTER:
.font(.footnote)
```

#### Fix 2.5: Change Role Button (Line 102) - **CRITICAL HIT TARGET**
```swift
// BEFORE (Lines 99-122):
.font(.system(size: 12, weight: .semibold))  // Line 99
.font(.system(size: 12, weight: .regular))   // Line 102
.frame(height: 40)  // LINE 122 - BELOW 44pt MINIMUM!

// AFTER:
.font(.caption.weight(.semibold))  // Line 99
.font(.caption)                     // Line 102
.frame(minHeight: 44)               // Line 122 - FIX IT!
```

#### Fix 2.6: Role Icon (Line 114)
```swift
// BEFORE:
.font(.system(size: 14))

// AFTER:
.font(.footnote)
```

#### Fix 2.7: Role Name (Line 117)
```swift
// BEFORE:
.font(.system(size: 14, weight: .semibold))

// AFTER:
.font(.footnote.weight(.semibold))
```

#### Fix 2.8: Create Account Button (Line 223)
```swift
// BEFORE:
.font(.system(size: 16, weight: .semibold))

// AFTER:
.font(.callout.weight(.semibold))
```

#### Fix 2.9-2.11: Sign In Link (Lines 253, 259, 261)
```swift
// BEFORE (Line 253):
.font(.system(size: 14, weight: .regular))

// AFTER:
.font(.footnote)

// BEFORE (Line 259):
.font(.system(size: 14, weight: .semibold))

// AFTER:
.font(.footnote.weight(.semibold))

// BEFORE (Line 261):
.font(.system(size: 12, weight: .semibold))

// AFTER:
.font(.caption.weight(.semibold))
```

**Status:** ✅ Ready to implement

---

### FILE 3: EmailVerificationView.swift

**10 font size fixes**

#### Fix 3.1: Back Button (Lines 31, 34)
```swift
// BEFORE:
.font(.system(size: 14, weight: .semibold))

// AFTER:
.font(.footnote.weight(.semibold))
```

#### Fix 3.2: Headline (Line 53) - **CRITICAL**
```swift
// BEFORE:
.font(.system(size: 24, weight: .semibold))

// AFTER:
.font(.title2.weight(.semibold))
```

#### Fix 3.3: Subtitle (Line 57)
```swift
// BEFORE:
.font(.system(size: 14, weight: .regular))

// AFTER:
.font(.footnote)
```

#### Fix 3.4: Action Button (Line 102)
```swift
// BEFORE:
.font(.system(size: 16, weight: .semibold))

// AFTER:
.font(.callout.weight(.semibold))
```

#### Fix 3.5: Cooldown Timer (Line 132)
```swift
// BEFORE:
.font(.system(size: 12, weight: .regular))

// AFTER:
.font(.caption)
```

**Status:** ✅ Ready to implement

---

## PHASE 2: HIGH PRIORITY COMPONENTS

### FILE 4: LoginFormField.swift

**3 font size fixes + 1 icon scaling fix**
*Note: Used in both LoginView AND SignupView - fix once, benefit both!*

#### Fix 4.1: Label Text (Line 17)
```swift
// BEFORE:
.font(.system(size: 14, weight: .semibold))

// AFTER:
.font(.footnote.weight(.semibold))
```

#### Fix 4.2: Error Message (Line 51)
```swift
// BEFORE:
.font(.system(size: 12, weight: .regular))

// AFTER:
.font(.caption)
```

#### Fix 4.3: Icon Width (Line 24)
```swift
// BEFORE:
.frame(width: 20)

// AFTER:
@Environment(\.sizeCategory) var sizeCategory
var iconWidth: CGFloat {
  sizeCategory >= .xLarge ? 22 : 20
}
.frame(width: iconWidth)
```

**Status:** ✅ Ready to implement

---

### FILE 5: RoleSelectionCard.swift

**4 font size fixes + 2 icon scaling fixes**

#### Fix 5.1: Role Title (Line 19)
```swift
// BEFORE:
.font(.system(size: 16, weight: .semibold))

// AFTER:
.font(.callout.weight(.semibold))
```

#### Fix 5.2: Role Description (Line 23)
```swift
// BEFORE:
.font(.system(size: 12, weight: .regular))

// AFTER:
.font(.caption)
```

#### Fix 5.3: Role Icon (Line 13)
```swift
// BEFORE:
.font(.system(size: 28))

// AFTER:
@Environment(\.sizeCategory) var sizeCategory
var roleIconSize: CGFloat {
  sizeCategory >= .xLarge ? 30 : 28
}
.font(.system(size: roleIconSize))
```

#### Fix 5.4: Checkmark Icon (Line 31)
```swift
// BEFORE:
.font(.system(size: 24))

// AFTER:
var checkmarkSize: CGFloat {
  sizeCategory >= .xLarge ? 26 : 24
}
.font(.system(size: checkmarkSize))
```

**Status:** ✅ Ready to implement

---

### FILE 6: PasswordStrengthIndicator.swift

**4 font size fixes**

#### Fix 6.1: Strength Label (Line 49)
```swift
// BEFORE:
.font(.system(size: 12, weight: .regular))

// AFTER:
.font(.caption)
```

#### Fix 6.2: Strength Text (Line 56)
```swift
// BEFORE:
.font(.system(size: 12, weight: .semibold))

// AFTER:
.font(.caption.weight(.semibold))
```

#### Fix 6.3: Error List Text (Line 85)
```swift
// BEFORE:
.font(.system(size: 11, weight: .regular))

// AFTER:
.font(.caption2)
```

#### Fix 6.4: Bullet Point Icon (Line 80)
```swift
// BEFORE:
.font(.system(size: 4))  // Too small!

// AFTER:
.font(.system(size: 6))  // Or use "•" text with .caption
```

**Status:** ✅ Ready to implement

---

### FILE 7: TermsCheckbox.swift

**3 font size fixes + 1 icon scaling fix**

#### Fix 7.1: Agreement Text (Lines 27, 41)
```swift
// BEFORE:
.font(.system(size: 14, weight: .regular))

// AFTER:
.font(.footnote)
```

#### Fix 7.2: Links Text (Lines 33, 47)
```swift
// BEFORE:
.font(.system(size: 14, weight: .semibold))

// AFTER:
.font(.footnote.weight(.semibold))
```

#### Fix 7.3: Checkbox Icon (Line 12)
```swift
// BEFORE:
.font(.system(size: 18))

// AFTER:
@Environment(\.sizeCategory) var sizeCategory
var checkboxSize: CGFloat {
  sizeCategory >= .xLarge ? 20 : 18
}
.font(.system(size: checkboxSize))
```

#### Note: minHeight 44 at Line 57 - ALREADY GOOD ✓

**Status:** ✅ Ready to implement

---

### FILE 8: ErrorBanner.swift

**1 font size fix + 1 button hit target verification**

#### Fix 8.1: Error Message (Line 15)
```swift
// BEFORE:
.font(.system(size: 14, weight: .regular))

// AFTER:
.font(.footnote)
```

#### Fix 8.2: Close Button Hit Target (Lines 21-24)
```swift
// Verify close button has explicit frame
// If not, add:
.frame(minWidth: 44, minHeight: 44)
.contentShape(Rectangle())
```

**Status:** ✅ Ready to implement

---

## PHASE 3: MEDIUM PRIORITY (Optional for MVP)

### FILE 9: DashboardView.swift
**7 font size fixes**

- Line 17: Compass icon (size 64) → scale with sizeCategory
- Line 22: Welcome text (size 28) → `.title`
- Line 26: Email (size 16) → `.callout`
- Line 32: Debug label (size 12) → `.caption`
- Line 36: Debug token (size 12, monospaced) → add `.dynamicTypeSize()`
- Line 47: Error message (size 14) → `.footnote`
- Line 62: Logout button (size 16) → `.callout`

---

### FILE 10: InfoBanner.swift
**3 font size fixes + 1 icon scaling fix**

- Line 21: Title (size 14) → `.footnote`
- Line 23: Subtitle (size 12) → `.caption`
- Lines 47, 55: Icons (size 20) → scale with sizeCategory

---

### FILE 11: TimeoutBanner.swift
**1 font size fix**

- Line 12: Message (size 14) → `.footnote`

---

### FILE 12: VerificationStatusIcon.swift
**1 icon scaling fix**

- Line 25: Background (80x80) → scale with sizeCategory
- Lines 33, 45, 53: Icon size (40) → scale with sizeCategory

---

### FILE 13: LandingView.swift
**MOSTLY GOOD - Only 2 icon fixes needed**

- Line 28: Logo icon (size 80) → scale with sizeCategory
- Line 114: Feature icons (size 32) → scale with sizeCategory

---

## IMPLEMENTATION CHECKLIST

### Phase 1 (Critical - 1-1.5 hours)
- [ ] LoginView.swift - 8 fixes applied
- [ ] SignupView.swift - 8 fixes applied + critical button height fix at Line 122
- [ ] EmailVerificationView.swift - 5 fixes applied
- [ ] Build succeeds: `xcodebuild build -scheme TheRecruitingCompass ...`
- [ ] Tests pass: `xcodebuild test -scheme TheRecruitingCompass ...` (should be 126+)

### Phase 2 (High - 1-1.5 hours)
- [ ] LoginFormField.swift - 3 fixes applied
- [ ] RoleSelectionCard.swift - 6 fixes applied
- [ ] PasswordStrengthIndicator.swift - 4 fixes applied
- [ ] TermsCheckbox.swift - 3 fixes applied
- [ ] ErrorBanner.swift - 2 fixes applied
- [ ] Build succeeds
- [ ] Tests pass (should be 126+)

### Phase 3 (Medium - 45 min)
- [ ] DashboardView.swift - 7 fixes applied
- [ ] InfoBanner.swift - 4 fixes applied
- [ ] TimeoutBanner.swift - 1 fix applied
- [ ] VerificationStatusIcon.swift - 2 fixes applied
- [ ] LandingView.swift - 2 fixes applied
- [ ] Build succeeds
- [ ] Tests pass (should be 126+)

### Phase 4 (Testing - 1-2 hours)
- [ ] Build clean (0 errors, 0 warnings)
- [ ] Test at Small text size (0.88x)
- [ ] Test at Normal text size (1.0x)
- [ ] Test at Large text size (1.12x)
- [ ] Test at XL text size (1.23x)
- [ ] Test at XXL text size (1.35x)
- [ ] Verify no Phase 1 & 2 accessibility regressions
- [ ] Run full test suite (156+ expected)
- [ ] Manual VoiceOver testing at XXL
- [ ] Verify all button hit targets ≥44x44

---

## SUCCESS CRITERIA

✅ All 59 hard-coded font sizes replaced
✅ All 6 button hit targets fixed to 44x44 minimum
✅ All 8+ icons scale proportionally
✅ 126+ tests still passing (zero regressions)
✅ Build clean (0 errors, 0 warnings)
✅ Manual testing at all 5 text sizes verified
✅ Phase 1 & 2 accessibility features still work
✅ Ready for code review

---

**Status: READY TO IMPLEMENT**
