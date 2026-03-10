import SwiftUI

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
