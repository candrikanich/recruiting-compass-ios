# ViewModel Migration to @Observable - Batch Plan
**Created:** 2026-02-15
**Goal:** Migrate all 22 ViewModels from ObservableObject to @Observable

---

## Migration Strategy

**Approach:** Batch migrations by feature area, test after each batch, commit separately

---

## Batch 1: List ViewModels (Priority)
**Focus:** Main list screens with similar patterns

1. ✅ NotificationsListViewModel - COMPLETE (already done)
2. ⏳ CoachesListViewModel
3. ⏳ SchoolsListViewModel
4. ⏳ InteractionsListViewModel

**Why first:** High traffic screens, most similar to completed NotificationsListViewModel

---

## Batch 2: Add/Create ViewModels
**Focus:** Form-based creation screens

5. ⏳ AddCoachViewModel
6. ⏳ AddSchoolViewModel
7. ⏳ AddInteractionViewModel

**Why second:** Similar form patterns, dependencies on Batch 1

---

## Batch 3: Detail ViewModels
**Focus:** Detail/read screens

8. ⏳ CoachDetailViewModel
9. ⏳ SchoolDetailViewModel
10. ⏳ InteractionDetailViewModel
11. ⏳ DashboardViewModel

**Why third:** Simpler than forms, lower risk

---

## Batch 4: Auth ViewModels
**Focus:** Authentication flows

12. ⏳ LoginViewModel
13. ⏳ SignupViewModel
14. ⏳ ForgotPasswordViewModel
15. ⏳ ResetPasswordViewModel
16. ⏳ EmailVerificationViewModel

**Why fourth:** Critical path, needs careful testing

---

## Batch 5: Preferences ViewModels
**Focus:** Settings and preferences

17. ⏳ HomeLocationViewModel
18. ⏳ SchoolPreferencesViewModel
19. ⏳ DashboardCustomizationViewModel
20. ⏳ PlayerDetailsViewModel
21. ⏳ NotificationPreferencesViewModel

**Why fifth:** Lower priority, less frequently used

---

## Batch 6: Family & Template
**Focus:** Remaining ViewModels

22. ⏳ FamilyManagementViewModel
23. ⏳ ExampleScreenViewModel (template)

**Why last:** Template needs to be reference implementation

---

## Per-ViewModel Checklist

For each ViewModel:
- [ ] Remove `import Combine`
- [ ] Add `import Observation`
- [ ] Change `ObservableObject` → `@Observable`
- [ ] Remove all `@Published` wrappers
- [ ] Keep `@MainActor` annotation
- [ ] Keep `private(set)` for read-only properties
- [ ] Update corresponding View: `@StateObject` → `@State`
- [ ] Add View initializer if needed
- [ ] Run specific tests
- [ ] Verify build passes

---

## Test Strategy

After each batch:
1. Run unit tests for migrated ViewModels
2. Run integration tests if applicable
3. Build entire project
4. Fix any compilation errors
5. Commit batch

---

## Current Progress

**Completed:** 1/22 (NotificationsListViewModel)
**In Progress:** Batch 1 (List ViewModels)
**Next:** CoachesListViewModel, SchoolsListViewModel, InteractionsListViewModel
