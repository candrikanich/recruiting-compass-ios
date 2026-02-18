import SwiftUI

struct EventDetailView: View {
  @State private var viewModel: EventDetailViewModel

  init(eventId: String, eventsService: EventsManaging = EventsServiceImpl()) {
    _viewModel = State(initialValue: EventDetailViewModel(
      eventsService: eventsService,
      eventId: eventId
    ))
  }

  // MARK: - Body

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.event == nil {
        ProgressView("Loading event...")
          .accessibilityLabel("Loading event details")
      } else if let errorMessage = viewModel.error, viewModel.event == nil {
        errorState(message: errorMessage)
      } else if let event = viewModel.event {
        eventContent(event)
      }
    }
    .navigationTitle(viewModel.event?.name ?? "Event")
    .navigationBarTitleDisplayMode(.large)
    .task {
      await viewModel.loadEvent()
    }
    .alert("Error", isPresented: Binding(
      get: { viewModel.error != nil && viewModel.event != nil },
      set: { if !$0 { viewModel.error = nil } }
    )) {
      Button("Retry") { Task { await viewModel.loadEvent() } }
      Button("OK", role: .cancel) { viewModel.error = nil }
    } message: {
      Text(viewModel.error ?? "")
    }
  }

  // MARK: - Content

  private func eventContent(_ event: FullEvent) -> some View {
    List {
      headerSection(event)
      if event.address != nil || event.city != nil || event.location != nil {
        locationSection(event)
      }
      if event.description != nil || event.url != nil {
        detailsSection(event)
      }
      if event.performanceNotes != nil {
        performanceSection(event)
      }
    }
    .listStyle(.insetGrouped)
  }

  // MARK: - Header Section

  private func headerSection(_ event: FullEvent) -> some View {
    Section {
      HStack {
        EventTypeBadge(type: event.type)
        Spacer()
        EventStatusBadge(registered: event.registered, attended: event.attended)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(EventType(rawValue: event.type)?.displayName ?? event.type), \(statusLabel(event))")

      Label(viewModel.formattedDateRange, systemImage: "calendar")
        .accessibilityLabel("Date: \(viewModel.formattedDateRange)")

      if let startTime = event.startTime, !startTime.isEmpty {
        Label(timeRange(start: startTime, end: event.endTime), systemImage: "clock")
          .accessibilityLabel("Time: \(timeRange(start: startTime, end: event.endTime))")
      }

      if let checkinTime = event.checkinTime, !checkinTime.isEmpty {
        Label("Check-in: \(checkinTime)", systemImage: "checkmark.circle")
          .accessibilityLabel("Check-in time: \(checkinTime)")
      }

      if let cost = event.cost {
        Label(cost == 0 ? "Free" : String(format: "$%.2f", cost), systemImage: "dollarsign.circle")
          .accessibilityLabel(cost == 0 ? "Free event" : String(format: "Cost: $%.2f", cost))
      }

      if let source = event.eventSource, !source.isEmpty {
        Label(EventSource(rawValue: source)?.displayName ?? source, systemImage: "pin")
          .foregroundStyle(.secondary)
          .accessibilityLabel("Source: \(EventSource(rawValue: source)?.displayName ?? source)")
      }
    } header: {
      Text("Event Info")
    }
  }

  // MARK: - Location Section

  private func locationSection(_ event: FullEvent) -> some View {
    Section {
      if let address = event.address, !address.isEmpty {
        Label(address, systemImage: "mappin")
          .accessibilityLabel("Address: \(address)")
      }
      if let locationLine = viewModel.formattedLocation {
        Label(locationLine, systemImage: "location")
          .accessibilityLabel("Location: \(locationLine)")
      }
      if let venueName = event.location, !venueName.isEmpty {
        Label(venueName, systemImage: "building.2")
          .accessibilityLabel("Venue: \(venueName)")
      }
      if viewModel.hasLocation {
        Button {
          if let url = viewModel.getDirectionsURL() {
            UIApplication.shared.open(url)
          }
        } label: {
          Label("Get Directions", systemImage: "map")
        }
        .accessibilityLabel("Get directions to event location")
        .accessibilityHint("Opens Apple Maps")
      }
    } header: {
      Text("Location")
    }
  }

  // MARK: - Details Section

  private func detailsSection(_ event: FullEvent) -> some View {
    Section {
      if let description = event.description, !description.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Description")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(description)
            .font(.body)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Description: \(description)")
      }
      if let url = event.url, !url.isEmpty {
        Link(url, destination: URL(string: url) ?? URL(string: "https://example.com")!)
          .accessibilityLabel("Event link: \(url)")
      }
    } header: {
      Text("Details")
    }
  }

  // MARK: - Performance Section

  private func performanceSection(_ event: FullEvent) -> some View {
    Section {
      if let notes = event.performanceNotes, !notes.isEmpty {
        Text(notes)
          .accessibilityLabel("Performance notes: \(notes)")
      }
    } header: {
      Text("Performance Notes")
    }
  }

  // MARK: - Error State

  private func errorState(message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text(message)
        .multilineTextAlignment(.center)
      Button("Retry") {
        Task { await viewModel.loadEvent() }
      }
      .buttonStyle(.bordered)
    }
    .padding()
  }

  // MARK: - Helpers

  private func statusLabel(_ event: FullEvent) -> String {
    if event.attended { return "Attended" }
    if event.registered { return "Registered" }
    return "Not Registered"
  }

  private func timeRange(start: String, end: String?) -> String {
    guard let end, !end.isEmpty else { return start }
    return "\(start) – \(end)"
  }
}

// MARK: - Supporting Views

private struct EventTypeBadge: View {
  let type: String

  private var eventType: EventType? { EventType(rawValue: type) }

  var body: some View {
    Text(eventType?.displayName ?? type)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(badgeColor.opacity(0.15))
      .foregroundStyle(badgeColor)
      .clipShape(Capsule())
  }

  private var badgeColor: Color {
    switch eventType {
    case .showcase: return .purple
    case .camp: return .green
    case .officialVisit: return .blue
    case .unofficialVisit: return .cyan
    case .game: return .orange
    case nil: return .gray
    }
  }
}

private struct EventStatusBadge: View {
  let registered: Bool
  let attended: Bool

  var body: some View {
    Text(label)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(color.opacity(0.15))
      .foregroundStyle(color)
      .clipShape(Capsule())
  }

  private var label: String {
    if attended { return "Attended" }
    if registered { return "Registered" }
    return "Not Registered"
  }

  private var color: Color {
    if attended { return .green }
    if registered { return .blue }
    return .gray
  }
}
