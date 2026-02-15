# iOS Notifications Feature Design

**Date:** 2026-02-15
**Feature:** Notifications Timeline
**Spec Reference:** iOS_SPEC_Phase4_Notifications.md
**Implementation Approach:** Layered Bottom-Up (Data → Business Logic → UI → Assembly)

---

## Overview

Implement a comprehensive notifications timeline feature for iOS that displays user notifications with filtering, search, bulk actions, and navigation to related entities. Feature parity with the existing Nuxt web implementation.

---

## Requirements Summary

### User Requirements
- View all notifications sorted by scheduled time (newest first)
- Filter by type (follow-ups, deadlines, inbound, digest, offers, events)
- Search notifications by title or message content
- Mark individual notifications as read (tap card)
- Mark all notifications as read (bulk action)
- Delete individual notifications (swipe or tap X)
- Clear all read notifications (bulk action)
- Navigate to related entities (coaches, schools, offers, events) from notifications
- Pull-to-refresh to manually reload
- Auto-refresh when view appears

### iOS-Specific Requirements
- Tab bar item (5th tab) with unread badge count
- Direct navigation to detail views (not list views)
- Pull-to-refresh + auto-refresh on appear
- Full feature parity with web (all features in spec)

---

## Architecture

### File Structure

```
Features/Notifications/
├── Models/
│   ├── AppNotification.swift          # Main model (Codable, Identifiable, Sendable)
│   ├── NotificationType.swift          # Enum with display labels & emojis
│   ├── NotificationPriority.swift      # Enum with color mappings
│   ├── NotificationFilters.swift       # Filter state model
│   └── NotificationDestination.swift   # Navigation destination enum
├── Services/
│   ├── NotificationServiceProtocol.swift  # Protocol for DI/testing
│   └── NotificationService.swift          # Supabase implementation
├── ViewModels/
│   └── NotificationsListViewModel.swift   # @MainActor, @ObservableObject
├── Views/
│   └── NotificationsListView.swift        # Main page view
├── Components/
│   ├── NotificationCard.swift             # Individual notification card
│   ├── NotificationFilterChips.swift      # Horizontal filter chips
│   ├── NotificationSearchBar.swift        # Search input
│   ├── NotificationEmptyState.swift       # "All caught up" state
│   └── NotificationBulkActions.swift      # Mark all / Clear read buttons
```

### MVVM Pattern

- **Model:** AppNotification, NotificationType, NotificationPriority (Codable, Sendable)
- **Service:** NotificationServiceProtocol + NotificationService (async functions, no @Published)
- **ViewModel:** NotificationsListViewModel (@MainActor, @ObservableObject, all UI state)
- **View:** NotificationsListView + Components (presentation only, calls ViewModel methods)

### Key Architectural Decisions

1. **Protocol-Based Service:** `NotificationServiceProtocol` enables `MockNotificationService` for unit testing
2. **@MainActor ViewModel:** All UI state updates are thread-safe
3. **Sendable Models:** Safe for concurrent contexts
4. **Component Separation:** Each UI element independently testable for accessibility
5. **Client-Side Filtering:** No server calls when changing filters/search (computed property)

---

## Data Flow & State Management

### ViewModel State

```swift
@MainActor
class NotificationsListViewModel: ObservableObject {
    // Data
    @Published private(set) var notifications: [AppNotification] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    // Filters & Search
    @Published var activeFilter: NotificationType? = nil  // nil = "All"
    @Published var searchQuery: String = ""

    // Navigation
    @Published var navigationPath: [NotificationDestination] = []

    // Computed Properties
    var filteredNotifications: [AppNotification] { /* filter + search logic */ }
    var unreadCount: Int { /* count where readAt == nil */ }
    var hasReadNotifications: Bool { /* any with readAt != nil */ }
    var hasUnreadNotifications: Bool { /* unreadCount > 0 */ }

    // Dependencies (Protocol-based DI)
    private let notificationService: NotificationServiceProtocol
    private let authManager: AuthManager

    // Methods
    func fetchNotifications() async
    func markAsRead(_ id: String) async
    func markAllAsRead() async
    func deleteNotification(_ id: String) async
    func deleteAllRead() async
    func refresh() async  // Pull-to-refresh
    func handleNotificationTap(_ notification: AppNotification) async
}
```

### Service Layer

```swift
protocol NotificationServiceProtocol {
    func fetchNotifications(userId: String) async throws -> [AppNotification]
    func markAsRead(id: String) async throws -> AppNotification
    func markAllAsRead(userId: String) async throws
    func deleteNotification(id: String) async throws
    func deleteAllRead(userId: String) async throws
}

class NotificationService: NotificationServiceProtocol {
    private let supabase = SupabaseManager.shared.client

    // Direct Supabase queries (no RPC functions)
    // SELECT * FROM notifications WHERE user_id = :userId ORDER BY scheduled_for DESC
    // UPDATE notifications SET read_at = now() WHERE id = :id
    // DELETE FROM notifications WHERE id = :id
}
```

### Data Flow Sequence

1. **View Appears** → `viewModel.fetchNotifications()` → Service → Supabase → Update `@Published notifications`
2. **User Taps Card** → `handleNotificationTap()` → `markAsRead(id)` → Update Supabase → Update local state → Navigate to detail
3. **Pull-to-Refresh** → `viewModel.refresh()` → Re-fetch from Supabase
4. **Filter/Search** → Local client-side filtering on `filteredNotifications` computed property (no server call)
5. **Bulk Actions** → Update multiple records → Re-fetch to ensure consistency

### Optimistic Updates

- **Mark as read:** Update local state immediately, rollback on error
- **Delete:** Remove from array immediately, rollback on error
- Provides instant UI feedback while network request completes

---

## UI Components & Styling

### NotificationCard

- **Layout:** HStack with emoji/icon, VStack (title, message, timestamp), delete button
- **Unread Styling:** Blue left border (4pt), blue-tinted background, semibold title, blue title color
- **Read Styling:** Gray left border (4pt), white background, regular title, primary color
- **Priority Badge:** HIGH (red), NORMAL (blue), LOW (gray) with colored backgrounds
- **Truncation:** Title 2 lines max, message 3 lines max, ellipsis
- **Accessibility:** Combined element with label: "[unread] [priority] [type]: [title]. [timestamp]"
- **Tap Target:** Full card 44pt minimum height

### NotificationFilterChips

- **Layout:** Horizontal ScrollView with "All" + NotificationType.allCases chips
- **Active Styling:** Blue fill, white text
- **Inactive Styling:** White fill, gray text, gray border
- **Chips:** "All", "🔔 Follow-ups", "⏰ Deadlines", "📧 Inbound", "📊 Digest", "🎉 Offers", "📅 Events"
- **Accessibility:** Each chip announces active/inactive state

### NotificationSearchBar

- **Component:** Standard iOS search field with placeholder "Search notifications..."
- **Binding:** Two-way bind to `viewModel.searchQuery`
- **Debouncing:** Not needed (computed property recalculates instantly)

### NotificationBulkActions

- **Mark All as Read Button:** Shows when `hasUnreadNotifications == true`
- **Clear Read Button:** Shows when `hasReadNotifications == true`
- **Styling:** Blue button (mark all), Red button (clear read)
- **Confirmation:** Alert dialog for "Clear read" action

### NotificationEmptyState

- **Display:** When `filteredNotifications.isEmpty`
- **Content:** "No notifications" title, "You're all caught up!" subtitle
- **Icon:** Bell with checkmark (SF Symbol)

### Styling Constants

| Element | Unread | Read |
|---------|--------|------|
| Left Border | Blue (#3B82F6), 4pt | Gray (#9CA3AF), 4pt |
| Background | Blue-tinted (#EFF6FF) | White |
| Title Weight | Semibold | Regular |
| Title Color | Blue-900 (#1E40AF) | Primary |

**Priority Badge Colors:**
- HIGH: Background #FEE2E2, Text #B91C1C
- NORMAL: Background #DBEAFE, Text #1D4ED8
- LOW: Background #F3F4F6, Text #4B5563

### Date Formatting (Relative)

- < 60 seconds: "just now"
- < 1 hour: "Xm ago"
- < 24 hours: "Xh ago"
- < 7 days: "Xd ago"
- Older: "Jan 15" (abbreviated month + day)

---

## Navigation

### Tab Bar Integration

Add 5th tab to main TabView:

```swift
NotificationsListView()
    .tabItem {
        Label("Notifications", systemImage: "bell.fill")
    }
    .badge(notificationsViewModel.unreadCount > 0 ? notificationsViewModel.unreadCount : nil)
```

### Action URL Mapping

When user taps a notification:
1. Mark as read (if unread)
2. Parse `action_url` or use `related_entity_type` + `related_entity_id`
3. Navigate to appropriate destination

**Web Route → iOS Destination Mapping:**
- `/coaches?highlight=123` → `.coachDetail(id: "123")`
- `/schools/abc` → `.schoolDetail(id: "abc")`
- `/offers?highlight=456` → `.offerDetail(id: "456")`
- `/events/789` → `.eventDetail(id: "789")`
- `/interactions/xyz` → `.interactionDetail(id: "xyz")`

### NotificationDestination Enum

```swift
enum NotificationDestination: Hashable {
    case coachDetail(id: String)
    case schoolDetail(id: String)
    case interactionDetail(id: String)
    case offerDetail(id: String)
    case eventDetail(id: String)
}
```

### Navigation Implementation

- Use `@Published var navigationPath: [NotificationDestination] = []` in ViewModel
- Push destination onto path when notification tapped
- View uses `.navigationDestination(for: NotificationDestination.self)`
- Navigation stays within Notifications tab (modal/pushed detail views)

---

## Error Handling & Edge Cases

### Error Types

```swift
enum NotificationError: LocalizedError {
    case notAuthenticated
    case networkTimeout
    case serverError(Int)
    case invalidActionUrl(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Session expired. Please log in again."
        case .networkTimeout:
            return "Network timeout. Pull to refresh to try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .invalidActionUrl:
            return "Unable to navigate to this item."
        }
    }
}
```

### Error Display Strategy

- **Fetch/Refresh Errors:** Show `ErrorBanner` at top of list (same pattern as Dashboard)
- **Mutation Errors:** Show brief Toast message (mark-as-read, delete failures)
- **Retry:** Pull-to-refresh allows easy retry for fetch errors
- **Session Expired (401):** Trigger `AuthManager.logout()` flow

### Edge Cases

| Edge Case | Handling |
|-----------|----------|
| Zero notifications | Show `NotificationEmptyState` |
| Very long titles | `.lineLimit(2)` with ellipsis |
| Very long messages | `.lineLimit(3)` with ellipsis |
| Rapid bulk actions | Disable button while `isLoading` |
| Delete while filtering | Remove from `notifications`, `filteredNotifications` recomputes |
| Invalid action_url | Log warning, show toast "Unable to navigate", stay on page |
| Missing related entity | Handle 404 on detail view, show "Not found" |
| Network offline | Service throws `networkTimeout`, show retry banner |
| Session expired | Catch 401, trigger logout |
| Concurrent mark-as-read | Optimistic update prevents flicker |

### Accessibility Edge Cases

- **VoiceOver with large lists:** SwiftUI List virtualization handles natively
- **Dynamic Type:** All fonts use semantic sizes (.body, .caption, etc.)
- **Reduce Motion:** Respect `UIAccessibility.isReduceMotionEnabled`

### Performance

- **Large lists (100+):** Use `LazyVStack` for virtualization
- **Scroll performance:** Minimal computation in card views
- **Memory:** No image loading, minimal overhead per card

---

## Testing Strategy

### Unit Tests (80%+ Coverage)

**AppNotificationTests.swift:**
- ✓ Codable encoding/decoding with snake_case keys
- ✓ `isRead` computed property
- ✓ NotificationType labels and emojis
- ✓ NotificationPriority color mappings

**NotificationServiceTests.swift:**
- ✓ fetchNotifications returns sorted by scheduledFor DESC
- ✓ markAsRead updates read_at timestamp
- ✓ markAllAsRead updates multiple records
- ✓ deleteNotification removes record
- ✓ deleteAllRead removes only read notifications
- ✓ Error handling: timeout, 401, 500
- Uses `MockSupabaseClient`

**NotificationsListViewModelTests.swift:**
- ✓ fetchNotifications updates @Published array
- ✓ filteredNotifications filters by type
- ✓ filteredNotifications searches title and message
- ✓ unreadCount computed property
- ✓ hasReadNotifications computed property
- ✓ markAsRead updates local state optimistically
- ✓ markAllAsRead updates all unread
- ✓ deleteNotification removes from array
- ✓ deleteAllRead removes only read
- ✓ Error handling sets errorMessage
- ✓ handleNotificationTap marks read and navigates
- Uses `MockNotificationService` + `MockAuthManager`

### Integration Tests

**NotificationServiceIntegrationTests.swift:**
- ✓ End-to-end with real Supabase (test environment)
- ✓ RLS policies enforce user_id filtering
- ✓ Concurrent operations don't conflict
- ✓ Bulk operations handle 100+ notifications

### Accessibility Tests

**NotificationCardAccessibilityTests.swift:**
- ✓ Unread card has correct label with status
- ✓ Delete button labeled "Delete notification"
- ✓ Priority badge text in card label
- ✓ All tap targets ≥ 44pt

**NotificationFilterChipsAccessibilityTests.swift:**
- ✓ Chips announce active/inactive state
- ✓ "All" chip accessible

**NotificationsListViewAccessibilityTests.swift:**
- ✓ Search bar has placeholder hint
- ✓ Bulk actions have descriptive labels
- ✓ Empty state readable by VoiceOver

### E2E Tests

**NotificationsE2ETests.swift:**
- ✓ Launch → Navigate to Notifications tab → See badge
- ✓ Tap unread → Card updates → Badge decreases
- ✓ Tap notification → Navigate to detail
- ✓ Filter → List updates
- ✓ Search → List filters
- ✓ Mark all as read → All cards update
- ✓ Delete → Removed from list
- ✓ Clear read → Only unread remain
- ✓ Pull-to-refresh → List refreshes
- ✓ Empty state → Message shown

---

## Implementation Plan (Layered Approach)

### Layer 1: Data Layer
1. Create `AppNotification` model with Codable conformance
2. Create `NotificationType` enum with labels/emojis
3. Create `NotificationPriority` enum with colors
4. Create `NotificationServiceProtocol`
5. Implement `NotificationService` with Supabase queries
6. Write unit tests for models and service

### Layer 2: Business Logic Layer
1. Create `NotificationsListViewModel` with @Published state
2. Implement fetch, mark, delete methods
3. Implement computed properties (filteredNotifications, unreadCount)
4. Implement navigation handling
5. Write ViewModel unit tests with mocks

### Layer 3: UI Components Layer
1. Create `NotificationCard` component
2. Create `NotificationFilterChips` component
3. Create `NotificationSearchBar` component
4. Create `NotificationEmptyState` component
5. Create `NotificationBulkActions` component
6. Write accessibility tests for all components

### Layer 4: Assembly Layer
1. Create `NotificationsListView` assembling all components
2. Integrate tab bar with badge
3. Wire navigation with `.navigationDestination`
4. Add pull-to-refresh
5. Write E2E tests for full flows

---

## Team Structure

- **Feature Implementation:** Subagent-driven development of layers 1-4
- **Unit Tests:** Write tests for models, service, ViewModel (parallel with implementation)
- **E2E Tests:** Write UI tests for complete user flows (after Layer 4)
- **Refactor:** Review each layer for DRY, naming, code smells
- **A11y:** Audit all components for WCAG AA, VoiceOver, Dynamic Type

---

## Success Criteria

- ✓ All 126+ existing tests still pass
- ✓ 80%+ test coverage for Notifications feature
- ✓ All accessibility tests pass
- ✓ E2E tests cover happy paths and edge cases
- ✓ Code follows existing MVVM patterns
- ✓ Feature parity with web implementation
- ✓ Tab bar badge updates correctly
- ✓ Navigation to related entities works
- ✓ Pull-to-refresh and auto-refresh work
- ✓ Filter and search perform smoothly

---

## Out of Scope (Future Enhancements)

- Push notifications via APNs (Phase 5+)
- Real-time subscription to notifications table
- Notification creation UI (server-side only)
- Badge count on app icon (requires APNs setup)
- Swipe actions (can add in Phase 4.1 if desired)

---

## References

- **iOS Spec:** `/planning/iOS_SPEC_Phase4_Notifications.md`
- **Web Implementation:** `/pages/notifications.vue`, `composables/useNotifications.ts`
- **Web Types:** `types/models.ts` (Notification interface)
- **iOS Patterns:** `Features/Interactions/`, `Features/Coaches/` (MVVM examples)
- **iOS Testing:** `TheRecruitingCompassTests/Features/*/ViewModels/*Tests.swift`

---

**Design Approved By:** Chris Andrikanich
**Approval Date:** 2026-02-15
**Ready for Implementation:** ✅ Yes
