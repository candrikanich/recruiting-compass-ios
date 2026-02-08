import SwiftUI

struct UpcomingEventsWidget: View {
  let events: [Event]

  @State private var isShowingAll = false

  private var sortedEvents: [Event] {
    events.sorted { $0.eventDate < $1.eventDate }
  }

  private var visibleEvents: [Event] {
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
  let event: Event

  private var eventDateFormatted: String {
    guard let date = ISO8601DateFormatter().date(from: event.eventDate) else {
      return event.eventDate
    }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private var eventTypeIcon: String {
    switch event.eventType {
    case "visit": return "building.2"
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
        Text(event.title)
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
    .accessibilityLabel("\(event.eventType): \(event.title)")
    .accessibilityValue(eventDateFormatted)
  }
}

#Preview {
  UpcomingEventsWidget(
    events: [
      Event(
        id: "1",
        title: "Campus Visit - State University",
        description: "Official campus tour",
        eventDate: "2026-02-15T10:00:00Z",
        eventType: "visit",
        location: "State University, City",
        schoolId: "school-1",
        userId: "user-1",
        createdAt: "2026-02-01T12:00:00Z"
      ),
      Event(
        id: "2",
        title: "Summer Basketball Camp",
        description: "Elite skills camp",
        eventDate: "2026-06-20T09:00:00Z",
        eventType: "camp",
        location: "Tech College",
        schoolId: "school-2",
        userId: "user-1",
        createdAt: "2026-02-01T12:00:00Z"
      )
    ]
  )
  .padding()
}
