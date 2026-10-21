import SwiftUI

/// Freezes the target user/family ids at the moment the create-event sheet is opened,
/// matching the pattern in `EventsListView` so the form's `@State` survives an
/// `authManager`/`familyManager` republish mid-edit.
private struct PresentedFamily: Identifiable, Equatable {
  let id: String
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
  @State private var createEventLaunch = CreateEventLaunch()
  @Environment(FamilyManager.self) private var familyManager

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
        .font(.brand(.headline))
        .accessibilityAddTraits(.isHeader)

      Divider()

      if sortedEvents.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("No upcoming events scheduled")
            .font(.brand(.caption))
            .foregroundStyle(Color.secondaryText)

          Button(action: presentCreateEvent) {
            if createEventLaunch.isWaiting {
              ProgressView()
                .accessibilityLabel(String(localized: "Loading your family"))
            } else {
              Text("Add Event")
                .font(.brand(.caption, weight: .semibold))
                .foregroundStyle(Color.accentPrimary)
            }
          }
          .disabled(createEventLaunch.isWaiting)
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
                .font(.brand(.caption))
              Image(systemName: isShowingAll ? "chevron.up" : "chevron.down")
                .font(.brand(.caption))
                .accessibilityHidden(true)
            }
            .foregroundStyle(Color.accentPrimary)
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
            .font(.brand(.caption, weight: .semibold))
            .foregroundStyle(Color.accentPrimary)
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
    .sheet(item: presentedFamilyUnitId) { presented in
      NavigationStack {
        CreateEventView(
          eventsService: EventsServiceImpl(),
          userId: userId,
          familyUnitId: presented.id,
          onEventCreated: { _ in
            createEventLaunch.dismiss()
            onEventCreated?()
          }
        )
      }
    }
    .onChange(of: familyUnitId) { _, _ in familyDidChange() }
    .onChange(of: familyManager.membership) { _, _ in familyDidChange() }
    .onDisappear { createEventLaunch.cancel() }
    .alert(
      String(localized: "Couldn't load your family"),
      isPresented: showingLoadFailure
    ) {
      Button("Retry") { retryFamilyLoad() }
      Button("Cancel", role: .cancel) { createEventLaunch.dismiss() }
    } message: {
      Text("We need your family before you can add an event. Check your connection and try again.")
    }
  }

  /// Item binding over the launch phase; the sheet's `id` is the frozen family id.
  private var presentedFamilyUnitId: Binding<PresentedFamily?> {
    Binding(
      get: {
        if case .presenting(let id) = createEventLaunch.phase { PresentedFamily(id: id) } else { nil }
      },
      set: { if $0 == nil { createEventLaunch.dismiss() } }
    )
  }

  private var showingLoadFailure: Binding<Bool> {
    Binding(
      get: { createEventLaunch.phase == .failed },
      set: { if !$0 { createEventLaunch.dismiss() } }
    )
  }

  private func presentCreateEvent() {
    createEventLaunch.tap(familyUnitId: familyUnitId, membership: familyManager.membership)
  }

  private func familyDidChange() {
    createEventLaunch.familyChanged(familyUnitId: familyUnitId, membership: familyManager.membership)
  }

  private func retryFamilyLoad() {
    createEventLaunch.retry(membership: .unknown)
    Task {
      await familyManager.loadFamilyData()
      // A repeat failure leaves membership at .failed, so onChange never fires; settle the wait explicitly.
      familyDidChange()
    }
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
  .environment(FamilyManager())
}
