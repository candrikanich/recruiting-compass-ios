import SwiftUI

struct UpcomingEventsWidget: View {
  /// Sorted once at init rather than re-sorted on every body evaluation
  /// (this computed property used to be read up to 5 times per render).
  private let sortedEvents: [FullEvent]

  @State private var isShowingAll = false

  init(events: [FullEvent]) {
    self.sortedEvents = events.sorted { $0.startDate < $1.startDate }
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
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
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
