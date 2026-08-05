import SwiftUI

struct EventsListView: View {
  @Binding var path: [MorePath]

  @Environment(AuthManager.self) private var authManager
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var viewModel = EventsListViewModel()
  @State private var eventToDelete: FullEvent?
  @State private var showCreateEvent = false
  @State private var hapticWarningTrigger = 0
  @State private var hapticLightTrigger = 0

  private var showDeleteConfirmation: Binding<Bool> {
    Binding(
      get: { eventToDelete != nil },
      set: { if !$0 { eventToDelete = nil } }
    )
  }

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.events.isEmpty {
        loadingState
      } else if viewModel.events.isEmpty {
        emptyState
      } else {
        eventsContent
      }
    }
    .navigationTitle("Events")
    .navigationBarTitleDisplayMode(.inline)
    .searchable(text: $viewModel.searchText, prompt: "Search events...")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showCreateEvent = true
        } label: {
          Image(systemName: "plus")
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "Add new event"))
        .accessibilityHint("Opens form to create a new event")
      }
    }
    .task {
      await viewModel.loadEvents()
    }
    .refreshable {
      await viewModel.loadEvents()
    }
    .alert("Error", isPresented: $viewModel.isShowingErrorAlert, presenting: viewModel.errorMessage) { _ in
      Button("Retry") { Task { await viewModel.loadEvents() } }
      Button("OK", role: .cancel) { viewModel.errorMessage = nil }
    } message: { error in
      Text(error)
    }
    .sheet(isPresented: $showCreateEvent) {
      createEventSheet
    }
    .confirmationDialog("Delete Event?", isPresented: showDeleteConfirmation, titleVisibility: .visible) {
      if let event = eventToDelete {
        Button("Delete", role: .destructive) {
          hapticWarningTrigger += 1
          Task { await viewModel.deleteEvent(id: event.id) }
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      if let event = eventToDelete {
        Text("Delete \"\(event.name)\"? This cannot be undone.")
      }
    }
    .sensoryFeedback(.warning, trigger: hapticWarningTrigger)
    .sensoryFeedback(.impact(weight: .light), trigger: hapticLightTrigger)
  }

  // MARK: - Create Event Sheet

  @ViewBuilder
  private var createEventSheet: some View {
    if let userId = viewModel.targetUserId {
      NavigationStack {
        CreateEventView(
          eventsService: EventsServiceImpl(),
          userId: userId,
          onEventCreated: { _ in
            showCreateEvent = false
            Task { await viewModel.loadEvents() }
          }
        )
      }
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var eventsContent: some View {
    ScrollViewReader { proxy in
      List {
        if !viewModel.events.isEmpty {
          Section {
            EventAnalyticsCards(analytics: viewModel.analytics)
          }
          .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
          .listRowBackground(Color.clear)
        }

        calendarSection
        filterBar
        sortResultsBar

        if viewModel.filteredEvents.isEmpty {
          noResultsState
        } else {
          if !viewModel.upcomingEvents.isEmpty {
            Section("Upcoming") {
              ForEach(viewModel.upcomingEvents) { event in
                eventRow(event)
                  .id(event.id)
              }
            }
          }

          if !viewModel.pastEvents.isEmpty {
            Section("Past") {
              ForEach(viewModel.pastEvents) { event in
                eventRow(event)
                  .id(event.id)
              }
            }
          }
        }
      }
      .listStyle(.insetGrouped)
      .onChange(of: viewModel.selectedCalendarDate) { _, date in
        guard let date else { return }
        if let id = viewModel.eventsForDate(date).first?.id {
          if reduceMotion {
            proxy.scrollTo(id, anchor: .top)
          } else {
            withAnimation { proxy.scrollTo(id, anchor: .top) }
          }
        }
      }
    }
  }

  // MARK: - Calendar Section

  @ViewBuilder
  private var calendarSection: some View {
    Section {
      EventsCalendarView(
        title: viewModel.currentMonthTitle,
        days: viewModel.calendarDays,
        hasEvent: viewModel.hasEvent(on:),
        isCurrentMonth: viewModel.isCurrentMonth(_:),
        selectedDate: viewModel.selectedCalendarDate,
        onSelectDate: { date in viewModel.selectedCalendarDate = date },
        onPreviousMonth: { viewModel.navigateToPreviousMonth() },
        onNextMonth: { viewModel.navigateToNextMonth() }
      )
      .listRowInsets(EdgeInsets())
      .listRowBackground(Color.clear)
    }
  }

  // MARK: - Filter Bar

  @ViewBuilder
  private var filterBar: some View {
    Section {
      Picker("Type", selection: $viewModel.typeFilter) {
        Text("All Types").tag(EventType?.none)
        ForEach(EventType.allCases, id: \.self) { type in
          Text(type.displayName).tag(EventType?.some(type))
        }
      }
      .accessibilityLabel(String(localized: "Filter by event type"))

      Picker("Status", selection: $viewModel.statusFilter) {
        ForEach(StatusFilter.allCases, id: \.self) { status in
          Text(status.displayName).tag(status)
        }
      }
      .accessibilityLabel(String(localized: "Filter by registration status"))

      Picker("Date Range", selection: $viewModel.dateRangeFilter) {
        ForEach(DateRangeFilter.allCases, id: \.self) { range in
          Text(range.displayName).tag(range)
        }
      }
      .accessibilityLabel(String(localized: "Filter by date range"))

      if viewModel.hasActiveFilters {
        Button("Clear Filters", role: .destructive) {
          viewModel.clearFilters()
        }
        .accessibilityLabel(String(localized: "Clear all active filters"))
      }
    } header: {
      Text("Filters")
    }
  }

  // MARK: - Sort Results Bar

  @ViewBuilder
  private var sortResultsBar: some View {
    Section {
      HStack {
        Text("\(viewModel.filteredEvents.count) result\(viewModel.filteredEvents.count == 1 ? "" : "s")")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
        Picker("Sort", selection: $viewModel.sortBy) {
          ForEach(SortOption.allCases, id: \.self) { option in
            Text(option.displayName).tag(option)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel(String(localized: "Sort events"))
      }
    }
  }

  // MARK: - Event Row

  private func eventRow(_ event: FullEvent) -> some View {
    NavigationLink(value: MorePath.eventDetail(eventId: event.id)) {
      EventRowView(event: event)
    }
    .accessibilityLabel(rowAccessibilityLabel(event))
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button(role: .destructive) {
        hapticLightTrigger += 1
        eventToDelete = event
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }

  // MARK: - States

  @ViewBuilder
  private var loadingState: some View {
    LoadingStateView(message: "Loading events...")
      .accessibilityLabel(String(localized: "Loading events"))
  }

  @ViewBuilder
  private var emptyState: some View {
    ContentUnavailableView {
      Label("No Events Yet", systemImage: "calendar")
    } description: {
      Text("Create your first event to track camps, showcases, visits, and games.")
    } actions: {
      Button {
        showCreateEvent = true
      } label: {
        Text("Add Your First Event")
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity, minHeight: 44)
      }
      .buttonStyle(.borderedProminent)
    }
  }

  @ViewBuilder
  private var noResultsState: some View {
    Section {
      if viewModel.hasActiveFilters && viewModel.searchText.isEmpty {
        ContentUnavailableView {
          Label("No Matching Events", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
          Text("No events match your current filters.")
        } actions: {
          Button("Clear Filters") { viewModel.clearFilters() }
            .buttonStyle(.bordered)
        }
      } else {
        ContentUnavailableView.search(text: viewModel.searchText)
      }
    }
  }

  // MARK: - Helpers

  private func rowAccessibilityLabel(_ event: FullEvent) -> String {
    let type = EventType(rawValue: event.type)?.displayName ?? event.type
    let status = event.attended
      ? String(localized: "Attended")
      : event.registered ? String(localized: "Registered") : String(localized: "Not Registered")
    return String(localized: "\(type): \(event.name), \(event.startDate), \(status)")
  }
}
