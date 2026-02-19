# Visual QA & Dynamic Type Testing Guide

**Project:** TheRecruitingCompass iOS
**Date:** February 7, 2026
**Purpose:** Verify pixel-perfect styling and Dynamic Type support across devices
**Status:** Ready for manual testing

---

## Test Matrix

### Devices to Test
- [ ] iPhone SE (3rd gen) - 4.7" small screen
- [ ] iPhone 15 - 6.1" standard screen
- [ ] iPhone 15 Pro Max - 6.7" large screen

### Text Sizes to Test (iOS Settings)
- [ ] Extra Small (XS)
- [ ] Small (S)
- [ ] Medium (M) - Default
- [ ] Large (L)
- [ ] Extra Large (XL)
- [ ] XXL (Accessibility)
- [ ] XXXL (Accessibility)

---

## Pre-Testing Setup

### 1. Configure Xcode Scheme with Supabase Credentials

Get values from **Supabase Dashboard → Settings → API**. Never commit real credentials to git. If credentials were previously exposed, rotate the anon key in Supabase.

```bash
# Open Xcode
open TheRecruitingCompass/TheRecruitingCompass.xcodeproj

# Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables
# Add (use your project's values from Supabase Dashboard → Settings → API):
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

### 2. Build and Run

```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## Test Procedures

### Phase 3A: Default Text Size (M) - All Devices

#### Device 1: iPhone SE

**Launch & Navigate:**
1. [ ] Build app on iPhone SE simulator
2. [ ] Navigate through each screen:
   - [ ] Landing page
   - [ ] Login page
   - [ ] Signup → Role selection → Form
   - [ ] Email verification screen
   - [ ] Dashboard

**Visual Checks (Medium Text):**
- [ ] All text is readable (no cutoff)
- [ ] Buttons are at least 48pt tall
- [ ] Form fields have proper spacing (16pt padding)
- [ ] No horizontal scrolling required
- [ ] Icons align properly with text
- [ ] Spacing is consistent (24pt sections, 16pt elements, 8pt gaps)

**Screenshot:** Capture all 5 screens

---

#### Device 2: iPhone 15 (Standard)

**Repeat all checks above**
- [ ] Landing page
- [ ] Login page
- [ ] Signup flow (all 3 steps)
- [ ] Email verification
- [ ] Dashboard

**Expected:** Same layout as SE, slightly more whitespace

---

#### Device 3: iPhone 15 Pro Max (Large)

**Repeat all checks above**
- [ ] Landing page
- [ ] Login page
- [ ] Signup flow
- [ ] Email verification
- [ ] Dashboard

**Expected:** Similar layout, more generous spacing

---

### Phase 3B: Dynamic Type Testing - iPhone 15

**Set text size in iOS Settings:**
```
Settings → Accessibility → Display & Text Size → Larger Text
```

#### Extra Small (XS)
- [ ] All text is readable
- [ ] No text overlap
- [ ] Buttons still 48pt+ tall
- [ ] Form maintains alignment

#### Small (S)
- [ ] Same checks as XS

#### Medium (M) - Default
- [ ] Baseline test (should look normal)

#### Large (L)
- [ ] Text larger but readable
- [ ] No layout breaking
- [ ] Buttons expand to accommodate text
- [ ] Form fields resize properly

#### Extra Large (XL)
- [ ] All text still visible on screen
- [ ] No text cutoff
- [ ] Scrolling required if necessary
- [ ] Touch targets remain ≥44pt

#### XXL (Accessibility)
- [ ] Can scroll to see all content
- [ ] Buttons still functional
- [ ] No text overlap
- [ ] Hierarchy maintained

#### XXXL (Accessibility - Maximum)
- [ ] All content accessible via scrolling
- [ ] Critical buttons still tappable (≥44pt)
- [ ] Forms remain usable
- [ ] Layout doesn't break

**Screenshots:** Capture at each text size for:
- [ ] Landing page
- [ ] Signup form
- [ ] Login form
- [ ] Email verification

---

## Layout Specifications (Should Not Break)

### Spacing Rules
```
Section spacing:    24pt
Element spacing:    16pt
Component padding:  8pt
Button height:      48pt minimum
Touch target:       44pt × 44pt minimum
Form field height:  44pt minimum
```

### Font Scaling
- **H1 (Headlines):** Dynamic - scales with device size + text settings
- **H2 (Subheadings):** Dynamic
- **Body (Regular text):** Dynamic
- **Caption/Hints:** Dynamic (minimum 12pt)
- **Buttons:** Dynamic, 48pt container minimum

### Responsive Behavior Expected

**On Small Devices (SE) at Large Text:**
- Form fields stack vertically
- Buttons may wrap to full width
- Spacing reduces slightly to fit content

**On Large Devices (Pro Max) at Large Text:**
- More generous whitespace
- Content remains centered
- Buttons centered on screen

---

## Critical Paths to Test

### 1. Signup Flow at Max Text Size
```
Landing → "Create Account" →
Role Selection (3 cards) →
Signup Form (5 inputs) →
Email Verification
```

**Critical checks:**
- [ ] Role cards remain 3-across (or 2 if needed)
- [ ] Form labels don't overlap inputs
- [ ] Password strength meter visible
- [ ] Terms checkbox and links accessible
- [ ] "Create Account" button visible and tappable

### 2. Login Flow at Max Text Size
```
Landing → "Sign In" →
Email input → Password input →
"Remember me" checkbox →
"Sign in" button → Dashboard
```

**Critical checks:**
- [ ] All fields visible without scrolling
- [ ] Checkbox label visible
- [ ] "Forgot password?" link accessible
- [ ] Sign in button remains ≥48pt

### 3. Email Verification at Max Text Size
```
Pending state → Resend button → Cooldown timer
```

**Critical checks:**
- [ ] Headline + subtitle readable
- [ ] Status icon visible
- [ ] Resend button visible
- [ ] Cooldown timer (60s) displays correctly
- [ ] Back button accessible

---

## Bug Reporting Template

**If you encounter layout issues:**

```
**Device:** [iPhone SE / 15 / 15 Pro Max]
**Text Size:** [XS/S/M/L/XL/XXL/XXXL]
**Screen:** [Landing / Login / Signup / Verification / Dashboard]
**Issue:** [Description of visual problem]
**Expected:** [What should happen]
**Actual:** [What actually happens]
**Screenshot:** [Attached]
```

---

## Verification Checklist

### Final Sign-Off

- [ ] **Small devices (SE)** - All text sizes XS to XL tested
- [ ] **Standard devices (15)** - All text sizes M to XXXL tested
- [ ] **Large devices (Max)** - All text sizes M to XXXL tested
- [ ] **No layout breaking** at any text size
- [ ] **All buttons ≥48pt** at all sizes
- [ ] **No horizontal scrolling** (except within forms)
- [ ] **All interactive elements accessible** (VoiceOver compatible)
- [ ] **Screenshots captured** for all text sizes

### Approval Sign-Off

| Aspect | Status | Notes |
|--------|--------|-------|
| **Small Device (SE)** | ⬜ Test | Proceed when complete |
| **Standard Device (15)** | ⬜ Test | Proceed when complete |
| **Large Device (Max)** | ⬜ Test | Proceed when complete |
| **XS-XL Text Sizes** | ⬜ Test | Proceed when complete |
| **XXL-XXXL Accessibility** | ⬜ Test | Proceed when complete |
| **No Layout Issues** | ⬜ Verify | Proceed when verified |
| **All Buttons 48pt+** | ⬜ Verify | Proceed when verified |

---

## How to Document Results

### After Testing Each Device/Text Size

1. **Take screenshot:**
   ```bash
   # In Xcode simulator
   Cmd+S (Simulator menu)
   ```

2. **Save to docs/screenshots/:**
   ```
   docs/screenshots/iPhone-15-TextSize-L-Landing.png
   docs/screenshots/iPhone-15-TextSize-XXL-Signup.png
   docs/screenshots/iPhone-SE-TextSize-M-Login.png
   ```

3. **Update verification checklist above** with ✅ when complete

### Final Deliverables

When all tests pass:
1. [ ] Collect all screenshots in `docs/screenshots/`
2. [ ] Mark all checkboxes above as ✅
3. [ ] Create summary: "All visual QA tests passed on [date]"

---

## Success Criteria

**Phase 3 is COMPLETE when:**
- ✅ All 3 device sizes tested at M (default) text
- ✅ All text sizes (XS-XXXL) tested on 1 device
- ✅ No layout breaking at any configuration
- ✅ All buttons ≥48pt tall
- ✅ No horizontal scrolling
- ✅ All screenshots captured
- ✅ Verification checklist 100% complete

---

## Time Estimate

- 5 min per device × 3 devices = 15 min (default text)
- 10 min per text size × 6 sizes = 60 min (dynamic type)
- 15 min documentation = 15 min
- **Total: ~90 minutes**

---

## Ready to Test?

Run the app on your preferred device and follow the checklist above. When complete, update this document with test results.

```bash
# Quick start
open TheRecruitingCompass/TheRecruitingCompass.xcodeproj
# Then: Product → Run (Cmd+R)
```
