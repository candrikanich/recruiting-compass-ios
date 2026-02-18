import SwiftUI

struct EditEventSheet: View {
  @Binding var editData: EditEventData
  let isSaving: Bool
  let onSave: () -> Void
  let onCancel: () -> Void

  var body: some View {
    NavigationStack {
      Form {
        basicInfoSection
        dateTimeSection
        locationSection
        detailsSection
        statusSection
        performanceSection
      }
      .navigationTitle("Edit Event")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onCancel)
            .disabled(isSaving)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: onSave)
            .fontWeight(.semibold)
            .disabled(isSaving || editData.name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
      .interactiveDismissDisabled(isSaving)
    }
  }

  // MARK: - Sections

  private var basicInfoSection: some View {
    Section {
      TextField("Event Name", text: $editData.name)
        .accessibilityLabel("Event name, required")

      Picker("Type", selection: Binding(
        get: { editData.type ?? .showcase },
        set: { editData.type = $0 }
      )) {
        ForEach(EventType.allCases, id: \.self) { type in
          Text(type.displayName).tag(type)
        }
      }
      .accessibilityLabel("Event type")
    } header: {
      Text("Basic Info")
    }
  }

  private var dateTimeSection: some View {
    Section {
      TextField("Start Date (YYYY-MM-DD)", text: $editData.startDate)
        .accessibilityLabel("Start date")
      TextField("End Date (YYYY-MM-DD)", text: $editData.endDate)
        .accessibilityLabel("End date")
      TextField("Start Time", text: $editData.startTime)
        .accessibilityLabel("Start time")
      TextField("End Time", text: $editData.endTime)
        .accessibilityLabel("End time")
      TextField("Check-in Time", text: $editData.checkinTime)
        .accessibilityLabel("Check-in time")
    } header: {
      Text("Date & Time")
    }
  }

  private var locationSection: some View {
    Section {
      TextField("Venue / Location Name", text: $editData.location)
        .accessibilityLabel("Venue name")
      TextField("Address", text: $editData.address)
        .accessibilityLabel("Street address")
      TextField("City", text: $editData.city)
        .accessibilityLabel("City")
      TextField("State", text: $editData.state)
        .accessibilityLabel("State")
    } header: {
      Text("Location")
    }
  }

  private var detailsSection: some View {
    Section {
      TextField("Event URL", text: $editData.url)
        .keyboardType(.URL)
        .textInputAutocapitalization(.never)
        .accessibilityLabel("Event URL")
      TextField("Description", text: $editData.description, axis: .vertical)
        .lineLimit(3...6)
        .accessibilityLabel("Event description")

      Picker("Source", selection: Binding(
        get: { editData.eventSource ?? .other },
        set: { editData.eventSource = $0 }
      )) {
        ForEach(EventSource.allCases, id: \.self) { source in
          Text(source.displayName).tag(source)
        }
      }
      .accessibilityLabel("Event source")

      TextField("Cost", text: $editData.cost)
        .keyboardType(.decimalPad)
        .accessibilityLabel("Event cost")
    } header: {
      Text("Details")
    }
  }

  private var statusSection: some View {
    Section {
      Toggle("Registered", isOn: $editData.registered)
        .accessibilityLabel("Registered for event")
      Toggle("Attended", isOn: $editData.attended)
        .accessibilityLabel("Attended event")
    } header: {
      Text("Status")
    }
  }

  private var performanceSection: some View {
    Section {
      TextField("Performance Notes", text: $editData.performanceNotes, axis: .vertical)
        .lineLimit(3...6)
        .accessibilityLabel("Performance notes")
    } header: {
      Text("Performance")
    }
  }
}
