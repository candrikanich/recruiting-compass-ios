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
        .accessibilityLabel(String(localized: "Add custom preference"))
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
    .sensoryFeedback(.success, trigger: viewModel.hapticSuccessTrigger)
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
