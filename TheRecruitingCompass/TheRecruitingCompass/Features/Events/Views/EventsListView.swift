import SwiftUI

struct EventsListView: View {
  @Binding var path: [MorePath]

  @Environment(AuthManager.self) private var authManager
  @State private var viewModel = EventsListViewModel()
  @State private var eventToDelete: FullEvent? = nil
  @State private var showCreateEvent = false

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
        .accessibilityLabel("Add new event")
        .accessibilityHint("Opens form to create a new event")
      }
    }
    .task {
      await viewModel.loadEvents()
    }
    .refreshable {
      await viewModel.loadEvents()
    }
    .alert("Error", isPresented: .init(
      get: { viewModel.error != nil },
      set: { if !$0 { viewModel.error = nil } }
    ), presenting: viewModel.error) { _ in
      Button("Retry") { Task { await viewModel.loadEvents() } }
      Button("OK", role: .cancel) { viewModel.error = nil }
    } message: { error in
      Text(error)
    }
    .sheet(isPresented: $showCreateEvent) {
      createEventSheet
    }
    .confirmationDialog(
      "Delete \(eventToDelete?.name ?? "event")?",
      isPresented: Binding(
        get: { eventToDelete != nil },
        set: { if !$0 { eventToDelete = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        if let event = eventToDelete {
          HapticFeedbackManager.shared.warning()
          Task { await viewModel.deleteEvent(id: event.id) }
          eventToDelete = nil
        }
      }
      Button("Cancel", role: .cancel) { eventToDelete = nil }
    } message: {
      Text("This action cannot be undone.")
    }
  }

  // MARK: - Create Event Sheet

  @ViewBuilder
  private var createEventSheet: some View {
    if let userId = authManager.user?.id {
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
          withAnimation { proxy.scrollTo(id, anchor: .top) }
        }
      }
    }
  }

  // MARK: - Calendar Section

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

  private var filterBar: some View {
    Section {
      Picker("Type", selection: $viewModel.typeFilter) {
        Text("All Types").tag(EventType?.none)
        ForEach(EventType.allCases, id: \.self) { type in
          Text(type.displayName).tag(EventType?.some(type))
        }
      }
      .accessibilityLabel("Filter by event type")

      Picker("Status", selection: $viewModel.statusFilter) {
        ForEach(StatusFilter.allCases, id: \.self) { status in
          Text(status.rawValue).tag(status)
        }
      }
      .accessibilityLabel("Filter by registration status")

      Picker("Date Range", selection: $viewModel.dateRangeFilter) {
        ForEach(DateRangeFilter.allCases, id: \.self) { range in
          Text(range.rawValue).tag(range)
        }
      }
      .accessibilityLabel("Filter by date range")

      if viewModel.hasActiveFilters {
        Button("Clear Filters", role: .destructive) {
          viewModel.clearFilters()
        }
        .accessibilityLabel("Clear all active filters")
      }
    } header: {
      Text("Filters")
    }
  }

  // MARK: - Sort Results Bar

  private var sortResultsBar: some View {
    Section {
      HStack {
        Text("\(viewModel.filteredEvents.count) result\(viewModel.filteredEvents.count == 1 ? "" : "s")")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
        Picker("Sort", selection: $viewModel.sortBy) {
          ForEach(SortOption.allCases, id: \.self) { option in
            Text(option.rawValue).tag(option)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Sort events")
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
        HapticFeedbackManager.shared.lightImpact()
        eventToDelete = event
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }

  // MARK: - States

  private var loadingState: some View {
    ProgressView("Loading events...")
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityLabel("Loading events")
  }

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
    let status = event.attended ? "Attended" : event.registered ? "Registered" : "Not Registered"
    return "\(type): \(event.name), \(event.startDate), \(status)"
  }
}

// MARK: - Event Row View

private struct EventRowView: View {
  let event: FullEvent

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        typeBadge
        statusBadge
        Spacer()
      }

      Text(event.name)
        .font(.headline)
        .lineLimit(2)

      Label(formattedDate, systemImage: "calendar")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if let time = event.startTime, !time.isEmpty {
        Label(time, systemImage: "clock")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if let location = locationLine {
        Label(location, systemImage: "mappin")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      if let cost = event.cost, cost > 0 {
        Label(cost.formatted(.currency(code: "USD")), systemImage: "dollarsign.circle")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if let notes = event.performanceNotes, !notes.isEmpty {
        Text(notes)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .padding(.top, 2)
      }
    }
    .padding(.vertical, 4)
  }

  private var typeBadge: some View {
    let eventType = EventType(rawValue: event.type)
    return Text(eventType?.displayName ?? event.type)
      .font(.caption2)
      .fontWeight(.semibold)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(typeColor.opacity(0.15))
      .foregroundStyle(typeColor)
      .clipShape(Capsule())
  }

  private var statusBadge: some View {
    let label = event.attended ? "Attended" : event.registered ? "Registered" : "Not Registered"
    let color: Color = event.attended ? .green : event.registered ? .blue : .gray
    return Text(label)
      .font(.caption2)
      .fontWeight(.semibold)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(color.opacity(0.12))
      .foregroundStyle(color)
      .clipShape(Capsule())
  }

  private var typeColor: Color {
    switch EventType(rawValue: event.type) {
    case .showcase: return .purple
    case .camp: return .green
    case .officialVisit: return .blue
    case .unofficialVisit: return .cyan
    case .game: return .orange
    case nil: return .gray
    }
  }

  private var formattedDate: String {
    DateFormatting.isoDateRangeString(from: event.startDate, to: event.endDate)
  }

  private var locationLine: String? {
    var parts: [String] = []
    if let city = event.city, !city.isEmpty { parts.append(city) }
    if let state = event.state, !state.isEmpty { parts.append(state) }
    return parts.isEmpty ? nil : parts.joined(separator: ", ")
  }
}
