# Design System Components — iOS

---

## BadgeView

Generic semantic badge. Use for all domain status labels.

```swift
BadgeView(text: "Contacted", color: .blue)
BadgeView(text: "Email", color: .blue, icon: "envelope.fill")
BadgeView(text: "Interested", color: .slate, accessibilityLabel: "Status: Interested")
```

**Props:**
- `text: String` — label
- `color: BadgeColor` — semantic color
- `icon: String?` — SF Symbol name (optional)
- `accessibilityLabel: String?` — override for VoiceOver (defaults to text)

---

## FitScoreBadge

Score-to-color badge. Drives color from numeric score thresholds.

```swift
FitScoreBadge(score: 85)   // emerald
FitScoreBadge(score: 65)   // orange
FitScoreBadge(score: 45)   // red
FitScoreBadge(score: nil)  // hidden
```

---

## PriorityTierBadge

```swift
PriorityTierBadge(tier: .a)  // red — Top Choice
PriorityTierBadge(tier: .b)  // orange — Strong Interest
PriorityTierBadge(tier: .c)  // slate — Fallback
```

---

## StatusBadge

```swift
StatusBadge(status: .committed)   // emerald
StatusBadge(status: .contacted)   // blue
StatusBadge(status: .notPursuing) // red
```

---

## DivisionBadge

```swift
DivisionBadge(division: "D1")   // blue
DivisionBadge(division: "NAIA") // purple
```

Accepts raw String for flexibility (lowercased input handled internally).

---

## Skeleton Loading Components

Use for loading states before data arrives.

### ShimmerModifier

Applied via `.shimmer()` extension on any view. Respects `accessibilityReduceMotion`.

```swift
RoundedRectangle(cornerRadius: 4)
  .fill(Color.Brand.slate100)
  .frame(height: 14)
  .shimmer()
```

### ListRowSkeleton

Placeholder for a single list row.

```swift
ForEach(0..<5, id: \.self) { _ in
  ListRowSkeleton()
}
```

### CardSkeleton

Placeholder for a card (grid or list).

```swift
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
  ForEach(0..<4, id: \.self) { _ in CardSkeleton() }
}
```

### StatCardSkeleton

Dashboard stat card placeholder (existing component, updated with reduceMotion support).

```swift
StatCardSkeleton()
```

---

## Rules

- Prefer `BadgeView` over custom badge implementations
- Always use `BadgeColor` — never pass raw `Color` to badge components
- All skeleton components include required accessibility traits (`.updatesFrequently`)
- The `.shimmer()` modifier automatically disables animation when `accessibilityReduceMotion` is enabled
