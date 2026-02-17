import SwiftUI

struct CreateEventView: View {
  @State private var viewModel: CreateEventViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var showDiscardAlert = false

  let onEventCreated: (String) -> Void

  init(eventsService: EventsManaging, userId: String, onEventCreated: @escaping (String) -> Void) {
    _viewModel = State(initialValue: CreateEventViewModel(
      eventsService: eventsService,
      userId: userId
    ))
    self.onEventCreated = onEventCreated
  }

  // MARK: - Computed

  private var isShowingError: Binding<Bool> {
    Binding(
      get: { viewModel.error != nil },
      set: { if !$0 { viewModel.error = nil } }
    )
  }

  private var hasUnsavedChanges: Bool {
    viewModel.formData.type != nil ||
    !viewModel.formData.name.isEmpty ||
    !viewModel.formData.startDate.isEmpty
  }

  // MARK: - Body

  var body: some View {
    VStack(spacing: 0) {
      Form {
        eventInfoSection
        dateTimeSection
        locationSection
        eventDetailsSection
        performanceSection
      }

      bottomBar
    }
    .navigationTitle("Add New Event")
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button("Back") {
          if hasUnsavedChanges {
            showDiscardAlert = true
          } else {
            dismiss()
          }
        }
        .accessibilityLabel("Back to events list")
      }
    }
    .alert("Error", isPresented: isShowingError) {
      Button("OK", role: .cancel) { }
    } message: {
      Text(viewModel.error ?? "")
    }
    .alert("Discard Changes?", isPresented: $showDiscardAlert) {
      Button("Discard", role: .destructive) { dismiss() }
      Button("Keep Editing", role: .cancel) { }
    } message: {
      Text("You have unsaved changes that will be lost.")
    }
    .sheet(isPresented: $viewModel.showOtherSchoolModal) {
      OtherSchoolSheet(
        schoolName: $viewModel.otherSchoolName,
        onContinue: { viewModel.handleOtherSchool() },
        onCancel: {
          viewModel.showOtherSchoolModal = false
          viewModel.otherSchoolName = ""
        }
      )
    }
    .sheet(isPresented: $viewModel.showAddSchoolModal) {
      AddSchoolSheet(
        schoolName: $viewModel.newSchoolName,
        schoolLocation: $viewModel.newSchoolLocation,
        isSaving: viewModel.isLoading,
        onSave: { Task { await viewModel.saveNewSchool() } },
        onCancel: {
          viewModel.showAddSchoolModal = false
          viewModel.newSchoolName = ""
          viewModel.newSchoolLocation = ""
        }
      )
    }
    .disabled(viewModel.isSaving)
    .task {
      await viewModel.loadSchools()
    }
  }

  // MARK: - Section 1: Event Info

  private var eventInfoSection: some View {
    Section {
      Picker("Event Type *", selection: $viewModel.formData.type) {
        Text("-- Select a type --").tag(EventType?.none)
        ForEach(EventType.allCases, id: \.self) { type in
          Text(type.displayName).tag(EventType?.some(type))
        }
      }
      .accessibilityLabel("Event type, required field")
      .overlay(alignment: .bottom) {
        validationMessage(for: "type")
      }

      TextField("Event Name *", text: $viewModel.formData.name)
        .accessibilityLabel("Event name, required field")
        .overlay(alignment: .bottom) {
          validationMessage(for: "name")
        }

      schoolPicker

      Picker("Event Source", selection: $viewModel.formData.eventSource) {
        Text("-- Select source --").tag(EventSource?.none)
        ForEach(EventSource.allCases, id: \.self) { source in
          Text(source.displayName).tag(EventSource?.some(source))
        }
      }
      .accessibilityLabel("Event source, optional")

      HStack {
        Text("$")
          .accessibilityHidden(true)
        TextField("Cost", text: $viewModel.formData.cost)
          .keyboardType(.decimalPad)
          .accessibilityLabel("Event cost in dollars")
      }

      TextField("Event URL", text: $viewModel.formData.url)
        .keyboardType(.URL)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .accessibilityLabel("Event URL")
    } header: {
      Text("Event Info")
    }
  }

  // MARK: - School Picker

  private var schoolPicker: some View {
    Picker("School", selection: Binding(
      get: { viewModel.formData.schoolId ?? "none" },
      set: { viewModel.handleSchoolSelection($0) }
    )) {
      Text("-- Select a school --").tag("none")
      ForEach(viewModel.schools) { school in
        Text(school.name).tag(school.id)
      }
      Divider()
      Text("Other (not listed)").tag("other")
      Text("+ Add new school").tag("add_new")
    }
    .accessibilityLabel("School, optional")
  }

  // MARK: - Section 2: Date & Time

  private var dateTimeSection: some View {
    Section {
      TextField("Start Date * (YYYY-MM-DD)", text: $viewModel.formData.startDate)
        .accessibilityLabel("Start date, required field")
        .onChange(of: viewModel.formData.startDate) {
          viewModel.onStartDateChanged()
        }
        .overlay(alignment: .bottom) {
          validationMessage(for: "startDate")
        }

      TextField("Start Time (HH:MM)", text: $viewModel.formData.startTime)
        .accessibilityLabel("Start time, optional")
        .onChange(of: viewModel.formData.startTime) {
          viewModel.onStartTimeChanged()
        }

      TextField("End Date (YYYY-MM-DD)", text: $viewModel.formData.endDate)
        .accessibilityLabel("End date, optional")
        .overlay(alignment: .bottom) {
          validationMessage(for: "endDate")
        }

      TextField("End Time (HH:MM)", text: $viewModel.formData.endTime)
        .accessibilityLabel("End time, optional")

      TextField("Check-in Time (HH:MM)", text: $viewModel.formData.checkinTime)
        .accessibilityLabel("Check-in time, optional")
    } header: {
      Text("Date & Time")
    }
  }

  // MARK: - Section 3: Location

  private var locationSection: some View {
    Section {
      TextField("Street Address", text: $viewModel.formData.address)
        .accessibilityLabel("Street address")

      TextField("City", text: $viewModel.formData.city)
        .accessibilityLabel("City")

      TextField("State (e.g., GA)", text: $viewModel.formData.state)
        .textInputAutocapitalization(.characters)
        .accessibilityLabel("State abbreviation")
        .onChange(of: viewModel.formData.state) {
          if viewModel.formData.state.count > 2 {
            viewModel.formData.state = String(viewModel.formData.state.prefix(2))
          }
        }

      if viewModel.showGetDirections {
        Button {
          if let url = viewModel.getDirectionsURL() {
            UIApplication.shared.open(url)
          }
        } label: {
          Label("Get Directions", systemImage: "map")
        }
        .accessibilityLabel("Get directions to event location")
        .accessibilityHint("Opens Apple Maps with the event address")
      }
    } header: {
      Text("Location")
    }
  }

  // MARK: - Section 4: Event Details

  private var eventDetailsSection: some View {
    Section {
      TextField("Event Description", text: $viewModel.formData.description, axis: .vertical)
        .lineLimit(3...6)
        .accessibilityLabel("Event description")

      Toggle("Registered", isOn: $viewModel.formData.registered)
        .accessibilityLabel("Registered for event")

      Toggle("Attended", isOn: $viewModel.formData.attended)
        .accessibilityLabel("Attended event")
    } header: {
      Text("Event Details")
    }
  }

  // MARK: - Section 5: Performance

  private var performanceSection: some View {
    Section {
      TextField("Performance Notes", text: $viewModel.formData.performanceNotes, axis: .vertical)
        .lineLimit(4...8)
        .accessibilityLabel("Performance notes")
    } header: {
      Text("Performance")
    }
  }

  // MARK: - Bottom Bar

  private var bottomBar: some View {
    VStack(spacing: 12) {
      Button {
        Task {
          if let eventId = await viewModel.createEvent() {
            onEventCreated(eventId)
          }
        }
      } label: {
        Group {
          if viewModel.isSaving {
            HStack(spacing: 8) {
              ProgressView()
                .tint(.white)
                .accessibilityHidden(true)
              Text("Creating...")
            }
          } else {
            Text("Create Event")
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
      }
      .buttonStyle(.borderedProminent)
      .disabled(viewModel.isSubmitDisabled)
      .accessibilityLabel(viewModel.isSaving ? "Creating event" : "Create event")
      .accessibilityHint(viewModel.isSubmitDisabled ? "Complete all required fields first" : "Saves the event")

      Button {
        if hasUnsavedChanges {
          showDiscardAlert = true
        } else {
          dismiss()
        }
      } label: {
        Text("Cancel")
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
      }
      .buttonStyle(.bordered)
      .accessibilityLabel("Cancel and return to events")
    }
    .padding()
    .background(.bar)
  }

  // MARK: - Helpers

  @ViewBuilder
  private func validationMessage(for field: String) -> some View {
    if let message = viewModel.validationErrors[field] {
      Text(message)
        .font(.caption)
        .foregroundStyle(.red)
        .accessibilityLabel("Error: \(message)")
    }
  }
}
