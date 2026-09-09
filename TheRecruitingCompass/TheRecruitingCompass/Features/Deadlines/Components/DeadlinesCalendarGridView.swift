import SwiftUI

/// Month-grid calendar for the Deadlines "Calendar" view mode. Sunday-start
/// 6-week grid (`DeadlinesMerge.buildCalendarGrid`); days outside the
/// current month render dimmed but stay tappable (spillover selection).
/// Dot indicators use each item's category color; days are capped visually
/// at 3 dots to avoid overflow on a small cell.
struct DeadlinesCalendarGridView: View {
  let days: [CalendarDay]
  let itemsByDate: [String: [UnifiedDeadline]]
  @Binding var selectedDate: String?

  private static let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
  private static let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
  private static let maxDots = 3

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 0) {
        ForEach(Array(Self.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
          Text(symbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
      }
      .accessibilityHidden(true)

      LazyVGrid(columns: Self.columns, spacing: 4) {
        ForEach(days) { day in
          dayCell(day)
        }
      }
    }
    .padding(.horizontal)
  }

  @ViewBuilder
  private func dayCell(_ day: CalendarDay) -> some View {
    let items = itemsByDate[day.date] ?? []
    let isSelected = selectedDate == day.date

    Button {
      selectedDate = isSelected ? nil : day.date
    } label: {
      VStack(spacing: 4) {
        Text("\(day.dayNumber)")
          .font(.subheadline)
          .foregroundStyle(day.isCurrentMonth ? .primary : .secondary)
        HStack(spacing: 2) {
          ForEach(Array(items.prefix(Self.maxDots).enumerated()), id: \.offset) { _, item in
            Circle()
              .fill(item.color)
              .frame(width: 5, height: 5)
          }
        }
        .frame(height: 6)
      }
      .frame(maxWidth: .infinity, minHeight: 44)
      .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel(for: day, items: items))
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  private func accessibilityLabel(for day: CalendarDay, items: [UnifiedDeadline]) -> String {
    let base = day.date
    guard !items.isEmpty else { return base }
    return "\(base), \(items.count) deadline\(items.count == 1 ? "" : "s")"
  }
}
