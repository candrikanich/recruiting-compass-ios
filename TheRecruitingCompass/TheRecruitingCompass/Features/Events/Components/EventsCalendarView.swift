import SwiftUI

struct EventsCalendarView: View {
  let title: String
  let days: [Date]
  let hasEvent: (Date) -> Bool
  let isCurrentMonth: (Date) -> Bool
  let selectedDate: Date?
  let onSelectDate: (Date) -> Void
  let onPreviousMonth: () -> Void
  let onNextMonth: () -> Void

  private let columns = Array(repeating: GridItem(.flexible()), count: 7)
  private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

  var body: some View {
    VStack(spacing: 12) {
      navigationHeader
      weekdayHeader
      daysGrid
    }
    .padding()
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityLabel("Calendar showing \(title)")
  }

  @ViewBuilder
  private var navigationHeader: some View {
    HStack {
      Button(action: onPreviousMonth) {
        Image(systemName: "chevron.left")
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("Previous month")

      Spacer()

      Text(title)
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      Spacer()

      Button(action: onNextMonth) {
        Image(systemName: "chevron.right")
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("Next month")
    }
  }

  @ViewBuilder
  private var weekdayHeader: some View {
    LazyVGrid(columns: columns, spacing: 4) {
      ForEach(weekdays, id: \.self) { day in
        Text(day)
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(.secondary)
          .frame(minHeight: 20)
      }
    }
  }

  @ViewBuilder
  private var daysGrid: some View {
    LazyVGrid(columns: columns, spacing: 4) {
      ForEach(days, id: \.self) { date in
        DayCellView(
          date: date,
          isCurrentMonth: isCurrentMonth(date),
          hasEvent: hasEvent(date),
          isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
          isToday: Calendar.current.isDateInToday(date),
          onTap: { if hasEvent(date) { onSelectDate(date) } }
        )
      }
    }
  }
}

// MARK: - Day Cell

private struct DayCellView: View {
  let date: Date
  let isCurrentMonth: Bool
  let hasEvent: Bool
  let isSelected: Bool
  let isToday: Bool
  let onTap: () -> Void

  private var dayNumber: String {
    String(Calendar.current.component(.day, from: date))
  }

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 2) {
        Text(dayNumber)
          .font(.subheadline)
          .fontWeight(isToday ? .bold : .regular)
          .foregroundStyle(textColor)
          .frame(width: 32, height: 32)
          .background(backgroundShape)

        Circle()
          .fill(Color.accentColor)
          .frame(width: 4, height: 4)
          .opacity(hasEvent ? 1 : 0)
      }
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!hasEvent && !isToday)
    .accessibilityLabel(accessibilityLabel)
  }

  private var textColor: Color {
    if isToday { return .white }
    if !isCurrentMonth { return Color(.tertiaryLabel) }
    return .primary
  }

  @ViewBuilder
  private var backgroundShape: some View {
    if isToday {
      Circle().fill(Color.accentColor)
    } else if isSelected {
      Circle().fill(Color.accentColor.opacity(0.2))
    } else {
      Color.clear
    }
  }

  private var accessibilityLabel: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    let dateStr = formatter.string(from: date)
    let eventInfo = hasEvent ? "Has events" : "No events"
    return "\(dateStr). \(eventInfo)."
  }
}
