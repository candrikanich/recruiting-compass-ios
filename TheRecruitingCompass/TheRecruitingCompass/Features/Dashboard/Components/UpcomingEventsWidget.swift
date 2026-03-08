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
          .foregroundStyle(Color.secondaryText)
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
                .font(.caption)
                .accessibilityHidden(true)
            }
            .foregroundStyle(Color.accentBlue)
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
    .clipShape(.rect(cornerRadius: 12))
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
}

struct EventRow: View {
  let event: FullEvent

  private static let isoParser: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static let isoParserFallback: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  private static let dateOnlyParser: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  private static let dateOnlyDisplay: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
  }()

  private static let dateTimeDisplay: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
  }()

  private var eventDateFormatted: String {
    if let date = EventRow.isoParser.date(from: event.startDate)
      ?? EventRow.isoParserFallback.date(from: event.startDate) {
      return EventRow.dateTimeDisplay.string(from: date)
    }
    if let d = EventRow.dateOnlyParser.date(from: event.startDate) {
      return EventRow.dateOnlyDisplay.string(from: d)
    }
    return event.startDate
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
        .foregroundStyle(Color.primaryGreen)
        .frame(width: 32)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(event.name)
          .font(.subheadline)
          .fontWeight(.semibold)

        Text(eventDateFormatted)
          .font(.caption)
          .foregroundStyle(Color.secondaryText)

        if let location = event.location {
          Text(location)
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
      }

      Spacer()
    }
    .padding(12)
    .frame(minHeight: 44)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
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
        coachesPresent: nil,
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
        coachesPresent: nil,
        updatedAt: "2026-02-01T12:00:00Z"
      )
    ]
  )
  .padding()
}
