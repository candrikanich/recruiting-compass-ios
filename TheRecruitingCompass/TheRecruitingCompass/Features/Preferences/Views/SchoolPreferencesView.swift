import SwiftUI

struct SchoolPreferencesView: View {
  @State private var viewModel: SchoolPreferencesViewModel
  @Environment(\.editMode) private var editMode

  init(preferenceService: PreferenceManaging) {
    _viewModel = State(initialValue: SchoolPreferencesViewModel(preferenceService: preferenceService))
  }

  var body: some View {
    Form {
      // Templates Section
      Section {
        TemplateCard(
          title: "D1 Power Conference",
          description: "Focus on top-tier D1 programs",
          icon: "star.fill"
        ) {
          viewModel.requestTemplateApplication("D1 Power Conference")
        }

        TemplateCard(
          title: "Academic Excellence",
          description: "Prioritize academics and fit",
          icon: "graduationcap.fill"
        ) {
          viewModel.requestTemplateApplication("Academic Excellence")
        }

        TemplateCard(
          title: "Close to Home",
          description: "Stay within 300 miles",
          icon: "house.fill"
        ) {
          viewModel.requestTemplateApplication("Close to Home")
        }

        TemplateCard(
          title: "Best Fit (Balanced)",
          description: "Balance distance, academics, and division",
          icon: "scale.3d"
        ) {
          viewModel.requestTemplateApplication("Best Fit (Balanced)")
        }
      } header: {
        Text("Quick Templates")
      } footer: {
        Text("Templates provide starting criteria. You can customize after applying.")
          .font(.caption)
      }

      // Preferences List
      if viewModel.hasPreferences {
        Section {
          List {
            ForEach(viewModel.preferences.preferences) { preference in
              PreferenceRow(
                preference: preference,
                onToggleDealbreaker: {
                  viewModel.toggleDealbreaker(id: preference.id)
                }
              )
            }
            .onDelete(perform: viewModel.removePreference)
            .onMove(perform: viewModel.movePreference)
          }
        } header: {
          Text("Your Preferences (Priority Order)")
        } footer: {
          Text("Drag to reorder. Higher priorities match first.")
            .font(.caption)
        }
      } else {
        Section {
          Text("No preferences set. Apply a template or add your own.")
            .foregroundStyle(.secondary)
            .font(.callout)
        }
      }

      // Add Preference Section
      Section {
        Button {
          viewModel.showingAddSheet = true
        } label: {
          HStack {
            Image(systemName: "plus.circle.fill")
            Text("Add Custom Preference")
          }
        }
        .accessibilityLabel("Add custom preference")
      }
    }
    .navigationTitle("School Preferences")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        if viewModel.hasPreferences {
          EditButton()
            .accessibilityLabel(editMode?.wrappedValue == .active ? "Done editing" : "Edit preferences")
        }
      }

      ToolbarItem(placement: .principal) {
        SaveStatusView(status: viewModel.saveStatus)
      }
    }
    .overlay {
      PreferenceLoadingOverlay(
        isLoading: viewModel.isLoading,
        message: "Loading preferences..."
      )
    }
    .alert("Replace Existing Preferences?", isPresented: $viewModel.showingTemplateWarning) {
      Button("Cancel", role: .cancel) {
        viewModel.cancelTemplateApplication()
      }
      Button("Replace", role: .destructive) {
        viewModel.confirmTemplateApplication()
      }
    } message: {
      Text("Applying this template will replace your current preferences. This action cannot be undone.")
    }
    .preferenceErrorAlert(errorMessage: $viewModel.errorMessage)
    .sheet(isPresented: $viewModel.showingAddSheet) {
      AddPreferenceSheet(
        onAdd: { preference in
          viewModel.addPreference(preference)
          viewModel.showingAddSheet = false
        },
        onCancel: {
          viewModel.showingAddSheet = false
        }
      )
    }
    .task {
      await viewModel.loadPreferences()
    }
  }
}

// MARK: - Template Card Component

struct TemplateCard: View {
  let title: String
  let description: String
  let icon: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.title2)
          .foregroundStyle(.blue)
          .frame(width: 40)

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.primary)

          Text(description)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(title) template")
    .accessibilityHint(description)
  }
}

// MARK: - Preference Row Component

struct PreferenceRow: View {
  let preference: SchoolPreference
  let onToggleDealbreaker: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: categoryIcon)
        .foregroundStyle(categoryColor)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 4) {
        Text(preferenceLabel)
          .font(.subheadline)
          .fontWeight(.medium)

        Text(valueDescription)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      if preference.isDealbreaker {
        Text("DEALBREAKER")
          .font(.caption)
          .bold()
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.red)
          .clipShape(.rect(cornerRadius: 4))
      }

      Button {
        onToggleDealbreaker()
      } label: {
        Image(systemName: preference.isDealbreaker ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
          .foregroundStyle(preference.isDealbreaker ? .red : .gray)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(preference.isDealbreaker ? "Remove dealbreaker" : "Mark as dealbreaker")
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(preferenceLabel): \(valueDescription)\(preference.isDealbreaker ? ", dealbreaker" : "")")
  }

  private var categoryIcon: String {
    switch preference.category {
    case .location: return "mappin.circle.fill"
    case .academic: return "book.fill"
    case .program: return "sportscourt.fill"
    case .custom: return "star.fill"
    }
  }

  private var categoryColor: Color {
    switch preference.category {
    case .location: return .blue
    case .academic: return .green
    case .program: return .orange
    case .custom: return .purple
    }
  }

  private var preferenceLabel: String {
    switch preference.type {
    case "max_distance_miles": return "Max Distance"
    case "preferred_regions": return "Preferred Regions"
    case "preferred_states": return "Preferred States"
    case "min_academic_rating": return "Min Academic Rating"
    case "school_size": return "School Size"
    case "division": return "Division"
    case "conference_type": return "Conference Type"
    case "scholarship_required": return "Scholarship Required"
    case "must_have": return "Must Have"
    case "nice_to_have": return "Nice to Have"
    default: return preference.type
    }
  }

  private var valueDescription: String {
    switch preference.value {
    case .string(let str):
      return str
    case .int(let num):
      if preference.type == "max_distance_miles" {
        return "\(num) miles"
      }
      return "\(num)"
    case .bool(let bool):
      return bool ? "Yes" : "No"
    case .stringArray(let arr):
      return arr.joined(separator: ", ")
    }
  }
}

// MARK: - Add Preference Sheet

struct AddPreferenceSheet: View {
  let onAdd: (SchoolPreference) -> Void
  let onCancel: () -> Void

  @State private var selectedCategory: PreferencePreferenceCategory = .location
  @State private var selectedType: String = "max_distance_miles"
  @State private var intValue: Int = 500
  @State private var stringValue: String = ""
  @State private var boolValue: Bool = false
  @State private var selectedStates: Set<String> = []

  var body: some View {
    NavigationStack {
      Form {
        Picker("Category", selection: $selectedCategory) {
          Text("Location").tag(PreferencePreferenceCategory.location)
          Text("Academic").tag(PreferencePreferenceCategory.academic)
          Text("Program").tag(PreferencePreferenceCategory.program)
          Text("Custom").tag(PreferencePreferenceCategory.custom)
        }

        Picker("Type", selection: $selectedType) {
          ForEach(typesForCategory, id: \.self) { type in
            Text(typeLabel(type)).tag(type)
          }
        }

        // Value input based on type
        if requiresIntInput {
          Stepper("Value: \(intValue)", value: $intValue, in: 1...5000)
        } else if requiresBoolInput {
          Toggle("Required", isOn: $boolValue)
        } else {
          TextField("Value", text: $stringValue)
        }
      }
      .navigationTitle("Add Preference")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onCancel()
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            let preference = buildPreference()
            onAdd(preference)
          }
          .disabled(!isValid)
        }
      }
    }
  }

  private var typesForCategory: [String] {
    switch selectedCategory {
    case .location:
      return ["max_distance_miles", "preferred_regions", "preferred_states"]
    case .academic:
      return ["min_academic_rating", "school_size"]
    case .program:
      return ["division", "conference_type", "scholarship_required"]
    case .custom:
      return ["must_have", "nice_to_have"]
    }
  }

  private var requiresIntInput: Bool {
    ["max_distance_miles", "min_academic_rating"].contains(selectedType)
  }

  private var requiresBoolInput: Bool {
    selectedType == "scholarship_required"
  }

  private var isValid: Bool {
    if requiresIntInput {
      return intValue > 0
    } else if requiresBoolInput {
      return true
    } else {
      return !stringValue.isEmpty
    }
  }

  private func typeLabel(_ type: String) -> String {
    switch type {
    case "max_distance_miles": return "Max Distance (miles)"
    case "preferred_regions": return "Preferred Regions"
    case "preferred_states": return "Preferred States"
    case "min_academic_rating": return "Min Academic Rating (1-5)"
    case "school_size": return "School Size"
    case "division": return "Division"
    case "conference_type": return "Conference Type"
    case "scholarship_required": return "Scholarship Required"
    case "must_have": return "Must Have"
    case "nice_to_have": return "Nice to Have"
    default: return type
    }
  }

  private func buildPreference() -> SchoolPreference {
    let value: AnyCodableValue
    if requiresIntInput {
      value = .int(intValue)
    } else if requiresBoolInput {
      value = .bool(boolValue)
    } else {
      value = .string(stringValue)
    }

    return SchoolPreference(
      id: UUID().uuidString,
      category: selectedCategory,
      type: selectedType,
      value: value,
      priority: 0, // Will be set by ViewModel
      isDealbreaker: false
    )
  }
}

#Preview {
  let prefs = SchoolPreferences(
    preferences: [
      SchoolPreference(
        id: "1",
        category: .location,
        type: "max_distance_miles",
        value: .int(500),
        priority: 1,
        isDealbreaker: false
      ),
      SchoolPreference(
        id: "2",
        category: .program,
        type: "division",
        value: .stringArray(["D1", "D2"]),
        priority: 2,
        isDealbreaker: true
      )
    ],
    templateUsed: nil,
    lastUpdated: nil
  )

  return NavigationStack {
    SchoolPreferencesView(
      preferenceService: PreferencePreviewMock(defaultValue: prefs)
    )
  }
}
