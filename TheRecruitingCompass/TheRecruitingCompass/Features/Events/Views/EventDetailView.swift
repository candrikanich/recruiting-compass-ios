import SwiftUI

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct EventDetailView: View {
  private enum Layout {
    static let toastHorizontalPadding: CGFloat = 16
    static let toastVerticalPadding: CGFloat = 10
    static let toastBottomPadding: CGFloat = 20
    static let toastShadowRadius: CGFloat = 4
    static let toastDismissDelay: Duration = .seconds(2)
    static let errorSpacing: CGFloat = 16
  }

  @State private var viewModel: EventDetailViewModel
  @Environment(\.dismiss) private var dismiss

  @MainActor
  init(
    eventId: String,
    eventsService: EventsManaging? = nil,
    authManager: (any AuthManaging)? = nil
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
      } else if viewModel.event == nil && viewModel.isNotFound {
        notFoundView
      } else if let errorMessage = viewModel.error, viewModel.event == nil {
        errorState(message: errorMessage)
      } else if let event = viewModel.event {
        eventContent(event)
      } else {
        loadingOrEmptyState
      }
    }
    .navigationTitle(viewModel.event?.name ?? "Event")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar { toolbarMenu }
    .toolbar(.hidden, for: .tabBar)
    .task { await viewModel.loadAll() }
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
    .confirmationDialog("Delete Event", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
      Button("Delete", role: .destructive) { Task { await viewModel.deleteEvent() } }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Are you sure you want to delete this event? This action cannot be undone.")
    }
    .alert("Error", isPresented: .init(
      get: { viewModel.error != nil && viewModel.event != nil },
      set: { if !$0 { viewModel.error = nil } }
    ), presenting: viewModel.error) { _ in
      Button("Retry") { Task { await viewModel.loadAll() } }
      Button("OK", role: .cancel) { viewModel.error = nil }
    } message: { error in
      Text(error)
    }
    .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
      if shouldDismiss { dismiss() }
    }
    .overlay(alignment: .bottom) {
      if viewModel.showSuccessToast, let message = viewModel.successMessage {
        successToast(message)
      }
    }
    .sheet(item: Bindable(viewModel).exportFileURL) { url in
      ActivityShareSheet(activityItems: [url])
        .onDisappear { viewModel.cleanupExport(url: url) }
    }
    .sensoryFeedback(.success, trigger: viewModel.hapticSuccessTrigger)
    .sensoryFeedback(.error, trigger: viewModel.hapticErrorTrigger)
    .sensoryFeedback(.warning, trigger: viewModel.hapticWarningTrigger)
  }

  /// Shown when event is nil but not loading/error/notFound (e.g. after task cancellation).
  private var loadingOrEmptyState: some View {
    VStack(spacing: Layout.errorSpacing) {
      ProgressView("Loading event...")
        .accessibilityLabel("Loading event details")
      Button("Retry") { Task { await viewModel.loadAll() } }
        .buttonStyle(.bordered)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Not Found

  private var notFoundView: some View {
    VStack(spacing: Layout.errorSpacing) {
      Image(systemName: "calendar.badge.exclamationmark")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text("Event not found")
        .font(.headline)
        .foregroundStyle(.secondary)
      Button("Return to Events") {
        dismiss()
      }
      .buttonStyle(.bordered)
      .accessibilityLabel("Return to Events")
      .accessibilityHint("Dismisses this screen and returns to the events list")
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarMenu: some ToolbarContent {
    if viewModel.event != nil {
      ToolbarItemGroup(placement: .primaryAction) {
        Menu {
          if viewModel.event?.attended != true {
            Button(action: { Task { await viewModel.markAsAttended() } }) {
              Label("Mark as attended", systemImage: "checkmark.circle")
            }
          }
          Button(action: { viewModel.openEditForm() }) {
            Label("Edit event", systemImage: "pencil")
          }
          Button(action: { viewModel.startQuickLog() }) {
            Label("Log Interaction", systemImage: "bubble.left.and.text.bubble.right")
          }
          Button(action: { viewModel.startAddMetric() }) {
            Label("Add Metric", systemImage: "chart.bar")
          }
          Divider()
          Button(role: .destructive, action: { viewModel.confirmDelete() }) {
            Label("Delete event", systemImage: "trash")
          }
          .accessibilityHint("Permanently deletes this event")
        } label: {
          Image(systemName: "ellipsis.circle")
            .accessibilityLabel("Event actions")
        }
      }
    }
  }

  // MARK: - Content

  private func eventContent(_ event: FullEvent) -> some View {
    List {
      EventHeaderSection(
        event: event,
        formattedDateRange: viewModel.formattedDateRange,
        formattedCost: viewModel.formattedCost,
        costAccessibilityLabel: viewModel.costAccessibilityLabel
      )
      if event.address != nil || event.city != nil || event.location != nil {
        EventLocationSection(
          event: event,
          formattedLocation: viewModel.formattedLocation,
          hasLocation: viewModel.hasLocation,
          getDirectionsURL: viewModel.getDirectionsURL
        )
      }
      if event.description != nil || event.url != nil {
        EventDetailsSection(event: event)
      }
      CoachesPresentSection(
        schoolId: event.schoolId,
        coachesAtEvent: viewModel.coachesAtEvent,
        availableCoaches: viewModel.availableCoaches,
        selectedCoachId: $viewModel.selectedCoachId,
        onRemoveCoach: { id in await viewModel.removeCoach(id: id) },
        onAddCoach: { await viewModel.addCoach() }
      )
      MetricsSectionView(
        metrics: viewModel.metrics,
        showMetricForm: viewModel.showMetricForm,
        newMetricData: $viewModel.newMetricData,
        isSavingMetric: viewModel.isSavingMetric,
        onDeleteMetric: { id in await viewModel.deleteMetric(id: id) },
        onSaveMetric: { await viewModel.addMetric() },
        onStartAdd: { viewModel.startAddMetric() },
        onCancelAdd: { viewModel.clearMetricForm() },
        onExport: { viewModel.prepareCSVExport() }
      )
      if event.performanceNotes != nil {
        EventPerformanceSection(event: event)
      }
    }
    .listStyle(.insetGrouped)
    .refreshable { await viewModel.loadAll() }
  }

  // MARK: - Supporting Views

  private func errorState(message: String) -> some View {
    VStack(spacing: Layout.errorSpacing) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle).foregroundStyle(.secondary).accessibilityHidden(true)
      Text(message).multilineTextAlignment(.center)
      Button("Retry") { Task { await viewModel.loadAll() } }.buttonStyle(.bordered)
    }
    .padding()
  }

  private func successToast(_ message: String) -> some View {
    Text(message)
      .font(.subheadline).fontWeight(.medium).foregroundStyle(.white)
      .padding(.horizontal, Layout.toastHorizontalPadding)
      .padding(.vertical, Layout.toastVerticalPadding)
      .background(.green.gradient, in: Capsule())
      .shadow(radius: Layout.toastShadowRadius)
      .padding(.bottom, Layout.toastBottomPadding)
      .accessibilityAddTraits(.updatesFrequently)
      .transition(.opacity)
      .task {
        try? await Task.sleep(for: Layout.toastDismissDelay)
        withAnimation { viewModel.showSuccessToast = false }
      }
      .accessibilityLabel(message)
  }
}
