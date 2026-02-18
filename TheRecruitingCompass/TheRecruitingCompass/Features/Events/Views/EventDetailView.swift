import SwiftUI

struct EventDetailView: View {
  private enum Layout {
    static let toastHorizontalPadding: CGFloat = 16
    static let toastVerticalPadding: CGFloat = 10
    static let toastBottomPadding: CGFloat = 20
    static let toastShadowRadius: CGFloat = 4
    static let toastDismissDelay: Duration = .seconds(2)
    static let errorSpacing: CGFloat = 16
    static let descriptionSpacing: CGFloat = 4
    static let metricRowInsets = EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
  }

  @State private var viewModel: EventDetailViewModel
  @Environment(\.dismiss) private var dismiss

  init(
    eventId: String,
    eventsService: EventsManaging = EventsServiceImpl(),
    authManager: any AuthManaging = AuthManager.shared
  ) {
    _viewModel = State(initialValue: EventDetailViewModel(
      eventsService: eventsService,
      authManager: authManager,
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
    .toolbar {
      if viewModel.event != nil {
        ToolbarItemGroup(placement: .primaryAction) {
          Menu {
            if viewModel.event?.attended != true {
              Button(action: { Task { await viewModel.markAsAttended() } }) {
                Label("Mark Attended", systemImage: "checkmark.circle")
              }
            }
            Button(action: { viewModel.openEditForm() }) {
              Label("Edit Event", systemImage: "pencil")
            }
            Button(action: { viewModel.startQuickLog() }) {
              Label("Log Interaction", systemImage: "bubble.left.and.text.bubble.right")
            }
            Button(action: { viewModel.startAddMetric() }) {
              Label("Add Metric", systemImage: "chart.bar")
            }
            Divider()
            Button(role: .destructive, action: { viewModel.confirmDelete() }) {
              Label("Delete Event", systemImage: "trash")
            }
          } label: {
            Image(systemName: "ellipsis.circle")
              .accessibilityLabel("Event actions")
          }
        }
      }
    }
    .task {
      await viewModel.loadAll()
    }
    .sheet(isPresented: $viewModel.showEditSheet) {
      EditEventSheet(
        editData: $viewModel.editData,
        isSaving: viewModel.isSaving,
        onSave: { Task { await viewModel.updateEvent() } },
        onCancel: { viewModel.showEditSheet = false }
      )
    }
    .sheet(isPresented: $viewModel.showQuickLogSheet) {
      QuickLogInteractionSheet(
        data: $viewModel.interactionData,
        coaches: viewModel.schoolCoaches,
        isSubmitting: viewModel.isLoggingInteraction,
        onSave: { Task { await viewModel.logInteraction() } },
        onCancel: { viewModel.showQuickLogSheet = false }
      )
    }
    .confirmationDialog(
      "Delete Event",
      isPresented: $viewModel.showDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        Task { await viewModel.deleteEvent() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Are you sure you want to delete this event? This action cannot be undone.")
    }
    .alert("Error", isPresented: Binding(
      get: { viewModel.error != nil && viewModel.event != nil },
      set: { if !$0 { viewModel.error = nil } }
    )) {
      Button("Retry") { Task { await viewModel.loadAll() } }
      Button("OK", role: .cancel) { viewModel.error = nil }
    } message: {
      Text(viewModel.error ?? "")
    }
    .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
      if shouldDismiss { dismiss() }
    }
    .overlay(alignment: .bottom) {
      if viewModel.showSuccessToast, let message = viewModel.successMessage {
        successToast(message)
      }
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

      if !viewModel.coachesAtEvent.isEmpty || !viewModel.availableCoaches.isEmpty {
        coachesSection
      }

      if !viewModel.metrics.isEmpty || viewModel.showMetricForm {
        metricsSection
      }

      if event.performanceNotes != nil {
        performanceSection(event)
      }
    }
    .listStyle(.insetGrouped)
    .refreshable {
      await viewModel.loadAll()
    }
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
      .accessibilityLabel("\(event.name), \(EventType(rawValue: event.type)?.displayName ?? event.type), \(viewModel.formattedDateRange), \(statusLabel(event))")

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

      if let costText = viewModel.formattedCost {
        Label(costText, systemImage: "dollarsign.circle")
          .accessibilityLabel(viewModel.costAccessibilityLabel ?? "")
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
        .accessibilityLabel("Get directions to \(event.location ?? "event location")")
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
        VStack(alignment: .leading, spacing: Layout.descriptionSpacing) {
          Text("Description")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(description)
            .font(.body)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Description: \(description)")
      }
      if let url = event.url, !url.isEmpty, let linkURL = URL(string: url) {
        Link(url, destination: linkURL)
          .accessibilityLabel("Event link: \(url)")
      }
    } header: {
      Text("Details")
    }
  }

  // MARK: - Coaches Section

  private var coachesSection: some View {
    Section {
      ForEach(viewModel.coachesAtEvent) { coach in
        HStack {
          EventCoachCard(coach: coach)
          Spacer()
          Button(role: .destructive) {
            Task { await viewModel.removeCoach(id: coach.id) }
          } label: {
            Image(systemName: "minus.circle.fill")
              .foregroundStyle(.red)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Remove \(coach.fullName)")
        }
      }

      if !viewModel.availableCoaches.isEmpty {
        Picker("Add Coach", selection: Binding(
          get: { viewModel.selectedCoachId ?? "" },
          set: { viewModel.selectedCoachId = $0.isEmpty ? nil : $0 }
        )) {
          Text("Select a coach...").tag("")
          ForEach(viewModel.availableCoaches) { coach in
            Text(coach.fullName).tag(coach.id)
          }
        }
        .accessibilityLabel("Add coach to event")
        .onChange(of: viewModel.selectedCoachId) { _, newValue in
          if newValue != nil {
            Task { await viewModel.addCoach() }
          }
        }
      }
    } header: {
      HStack {
        Text("Coaches Present")
        Spacer()
        Text("\(viewModel.coachesAtEvent.count)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Metrics Section

  private var metricsSection: some View {
    Section {
      ForEach(viewModel.metrics) { metric in
        MetricCardView(metric: metric)
          .listRowInsets(Layout.metricRowInsets)
          .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
              Task { await viewModel.deleteMetric(id: metric.id) }
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
      }

      if viewModel.showMetricForm {
        EventMetricForm(
          data: $viewModel.newMetricData,
          isSaving: viewModel.isSavingMetric,
          onSave: { Task { await viewModel.addMetric() } },
          onCancel: { viewModel.clearMetricForm() }
        )
        .listRowInsets(Layout.metricRowInsets)
      }

      if !viewModel.showMetricForm {
        Button {
          viewModel.startAddMetric()
        } label: {
          Label("Add Metric", systemImage: "plus.circle")
        }
        .accessibilityLabel("Add a new performance metric")
      }
    } header: {
      HStack {
        Text("Performance Metrics")
        Spacer()
        Text("\(viewModel.metrics.count)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
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
    VStack(spacing: Layout.errorSpacing) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text(message)
        .multilineTextAlignment(.center)
      Button("Retry") {
        Task { await viewModel.loadAll() }
      }
      .buttonStyle(.bordered)
    }
    .padding()
  }

  // MARK: - Success Toast

  private func successToast(_ message: String) -> some View {
    Text(message)
      .font(.subheadline)
      .fontWeight(.medium)
      .foregroundStyle(.white)
      .padding(.horizontal, Layout.toastHorizontalPadding)
      .padding(.vertical, Layout.toastVerticalPadding)
      .background(.green.gradient, in: Capsule())
      .shadow(radius: Layout.toastShadowRadius)
      .padding(.bottom, Layout.toastBottomPadding)
      .transition(.move(edge: .bottom).combined(with: .opacity))
      .task {
        try? await Task.sleep(for: Layout.toastDismissDelay)
        withAnimation { viewModel.showSuccessToast = false }
      }
      .accessibilityLabel(message)
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
  private enum Layout {
    static let horizontalPadding: CGFloat = 10
    static let verticalPadding: CGFloat = 4
    static let backgroundOpacity: Double = 0.15
  }

  let type: String

  private var eventType: EventType? { EventType(rawValue: type) }

  var body: some View {
    Text(eventType?.displayName ?? type)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, Layout.horizontalPadding)
      .padding(.vertical, Layout.verticalPadding)
      .background(badgeColor.opacity(Layout.backgroundOpacity))
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
  private enum Layout {
    static let horizontalPadding: CGFloat = 10
    static let verticalPadding: CGFloat = 4
    static let backgroundOpacity: Double = 0.15
  }

  let registered: Bool
  let attended: Bool

  var body: some View {
    Text(label)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, Layout.horizontalPadding)
      .padding(.vertical, Layout.verticalPadding)
      .background(color.opacity(Layout.backgroundOpacity))
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
