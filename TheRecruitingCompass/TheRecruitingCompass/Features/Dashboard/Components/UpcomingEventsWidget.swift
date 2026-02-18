import SwiftUI

struct UpcomingEventsWidget: View {
  let events: [FullEvent]

  @State private var isShowingAll = false

  private var sortedEvents: [FullEvent] {
    events.sorted { $0.startDate < $1.startDate }
  }

  private var visibleEvents: [FullEvent] {
    isShowingAll ? sortedEvents : Array(sortedEvents.prefix(3))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Upcoming Events")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      Divider()

      if sortedEvents.isEmpty {
        Text("No upcoming events scheduled")
          .font(.caption)
          .foregroundColor(Color.secondaryText)
          .padding(.vertical)
      } else {
        VStack(spacing: 12) {
          ForEach(visibleEvents) { event in
            EventRow(event: event)
          }
        }

        if sortedEvents.count > 3 {
          Button(action: { isShowingAll.toggle() }) {
            HStack(spacing: 4) {
              Text(isShowingAll
                ? "Show less"
                : "Show \(sortedEvents.count - 3) more events")
                .font(.caption)
              Image(systemName: isShowingAll ? "chevron.up" : "chevron.down")
                .font(.caption2)
                .accessibilityHidden(true)
            }
            .foregroundColor(Color.accentBlue)
          }
          .accessibilityLabel(isShowingAll
            ? "Show fewer events"
            : "Show all \(sortedEvents.count) events")
          .accessibilityHint(isShowingAll
            ? "Collapses the list to show only 3 events"
            : "Expands the list to show all events")
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
}

struct EventRow: View {
  let event: FullEvent

  private var eventDateFormatted: String {
    guard let date = ISO8601DateFormatter().date(from: event.startDate) else {
      let dateOnly = DateFormatter()
      dateOnly.dateFormat = "yyyy-MM-dd"
      if let d = dateOnly.date(from: event.startDate) {
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: d)
      }
      return event.startDate
    }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private var eventTypeIcon: String {
    switch event.type {
    case "visit", "official_visit", "unofficial_visit": return "building.2"
    case "camp": return "figure.run"
    case "showcase": return "star.circle"
    case "game": return "sportscourt"
    default: return "calendar"
    }
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: eventTypeIcon)
        .font(.title3)
        .foregroundColor(Color.primaryGreen)
        .frame(width: 32)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(event.name)
          .font(.subheadline)
          .fontWeight(.semibold)

        Text(eventDateFormatted)
          .font(.caption)
          .foregroundColor(Color.secondaryText)

        if let location = event.location {
          Text(location)
            .font(.caption)
            .foregroundColor(Color.secondaryText)
        }
      }

      Spacer()
    }
    .padding(12)
    .frame(minHeight: 44)
    .background(Color(.secondarySystemBackground))
    .cornerRadius(8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(event.type): \(event.name)")
    .accessibilityValue(eventDateFormatted)
  }
}

#Preview {
  UpcomingEventsWidget(
    events: [
      FullEvent(
        id: "1",
        name: "Campus Visit - State University",
        type: "official_visit",
        schoolId: "school-1",
        location: "State University, City",
        address: nil,
        city: nil,
        state: nil,
        startDate: "2026-02-15",
        startTime: "10:00",
        endDate: nil,
        endTime: nil,
        checkinTime: nil,
        url: nil,
        description: "Official campus tour",
        eventSource: nil,
        cost: nil,
        registered: false,
        attended: false,
        performanceNotes: nil,
        userId: "user-1",
        createdAt: "2026-02-01T12:00:00Z",
        updatedAt: "2026-02-01T12:00:00Z"
      ),
      FullEvent(
        id: "2",
        name: "Summer Basketball Camp",
        type: "camp",
        schoolId: "school-2",
        location: "Tech College",
        address: nil,
        city: nil,
        state: nil,
        startDate: "2026-06-20",
        startTime: "09:00",
        endDate: nil,
        endTime: nil,
        checkinTime: nil,
        url: nil,
        description: "Elite skills camp",
        eventSource: nil,
        cost: nil,
        registered: false,
        attended: false,
        performanceNotes: nil,
        userId: "user-1",
        createdAt: "2026-02-01T12:00:00Z",
        updatedAt: "2026-02-01T12:00:00Z"
      )
    ]
  )
  .padding()
}
