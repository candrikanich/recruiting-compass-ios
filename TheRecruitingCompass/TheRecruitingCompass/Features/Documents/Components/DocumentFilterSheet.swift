import SwiftUI

struct DocumentFilterSheet: View {
  @Bindable var viewModel: DocumentsListViewModel

  var body: some View {
    NavigationStack {
      Form {
        Section("Type") {
          ForEach(DocumentType.allCases, id: \.self) { type in
            Button {
              viewModel.toggleType(type)
            } label: {
              HStack {
                Text("\(type.typeEmoji) \(type.label)")
                Spacer()
                if viewModel.selectedTypes.contains(type) {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                }
              }
            }
            .accessibilityLabel(String(localized: "\(type.label) filter"))
            .accessibilityAddTraits(viewModel.selectedTypes.contains(type) ? .isSelected : [])
          }
        }

        Section("School") {
          Picker("School", selection: $viewModel.selectedSchoolId) {
            Text("All Schools").tag(nil as String?)
            Text("General (No School)").tag("general" as String?)
            ForEach(viewModel.schools, id: \.id) { school in
              Text(school.name).tag(school.id as String?)
            }
          }
          .accessibilityLabel(String(localized: "Filter by school"))
        }

        Section("Status") {
          Toggle("Shared only", isOn: $viewModel.showSharedOnly)
            .accessibilityLabel(String(localized: "Show only shared documents"))
        }
      }
      .navigationTitle("Filter Documents")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            viewModel.isFilterSheetPresented = false
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          if viewModel.hasActiveFilters {
            Button("Clear") {
              viewModel.clearFilters()
            }
          }
        }
      }
    }
  }
}
