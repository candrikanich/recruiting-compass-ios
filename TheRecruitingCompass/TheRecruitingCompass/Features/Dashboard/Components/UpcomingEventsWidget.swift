import SwiftUI

/// Freezes the target user/family ids at the moment the create-event sheet is opened,
/// matching the pattern in `EventsListView` so the form's `@State` survives an
/// `authManager`/`familyManager` republish mid-edit.
private struct CreateEventContext: Identifiable {
  let id = UUID()
  let userId: String
  let familyUnitId: String
}

struct UpcomingEventsWidget: View {
  let familyUnitId: String
  let userId: String
  /// Reload the dashboard after a create so the new event appears in this widget.
  var onEventCreated: (() -> Void)?

  /// Sorted once at init rather than re-sorted on every body evaluation
  /// (this computed property used to be read up to 5 times per render).
  private let sortedEvents: [FullEvent]

  @State private var isShowingAll = false
  @State private var isShowingAllEvents = false
  @State private var createEventContext: CreateEventContext?

  init(events: [FullEvent], familyUnitId: String, userId: String, onEventCreated: (() -> Void)? = nil) {
    self.sortedEvents = events.sorted { $0.startDate < $1.startDate }
    self.familyUnitId = familyUnitId
    self.userId = userId
    self.onEventCreated = onEventCreated
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
        VStack(alignment: .leading, spacing: 8) {
          Text("No upcoming events scheduled")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)

          Button(action: presentCreateEvent) {
            Text("Add Event")
              .font(.caption.weight(.semibold))
              .foregroundStyle(Color.accentBlue)
          }
          .accessibilityHint("Opens the form to create a new event")
        }
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
                ? String(localized: "Show less")
                : String(localized: "Show \(sortedEvents.count - 3) more events"))
                .font(.caption)
              Image(systemName: isShowingAll ? "chevron.up" : "chevron.down")
                .font(.caption)
                .accessibilityHidden(true)
            }
            .foregroundStyle(Color.accentBlue)
          }
          .accessibilityLabel(String(localized: isShowingAll
            ? "Show fewer events"
            : "Show all \(sortedEvents.count) events"))
          .accessibilityHint(isShowingAll
            ? "Collapses the list to show only 3 events"
            : "Expands the list to show all events")
        }

        Button(action: { isShowingAllEvents = true }) {
          Text("View All Events")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentBlue)
        }
        .accessibilityHint("Opens the full events list")
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
    .sheet(isPresented: $isShowingAllEvents) {
      NavigationStack {
        EventsListView()
      }
    }
    .sheet(item: $createEventContext) { context in
      NavigationStack {
        CreateEventView(
          eventsService: EventsServiceImpl(),
          userId: context.userId,
          familyUnitId: context.familyUnitId,
          onEventCreated: { _ in
            createEventContext = nil
            onEventCreated?()
          }
        )
      }
    }
  }

  private func presentCreateEvent() {
    createEventContext = CreateEventContext(userId: userId, familyUnitId: familyUnitId)
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
    ],
    familyUnitId: "family-1",
    userId: "user-1"
  )
  .padding()
}
