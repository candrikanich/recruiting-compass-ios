import SwiftUI

struct DocumentEditSheet: View {
  @Bindable var viewModel: DocumentDetailViewModel

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Document title", text: $viewModel.editTitle, prompt: Text("e.g., Freshman Highlights 2025"))
            .accessibilityLabel("Document title")
            .onChange(of: viewModel.editTitle) { _, newValue in
              if newValue.count > 100 {
                viewModel.editTitle = String(newValue.prefix(100))
              }
            }
          if viewModel.editTitle.count >= 100 {
            Text("\(viewModel.editTitle.count)/100 characters")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } header: {
          Text("Required")
        }

        Section {
          Picker("School", selection: Binding(
            get: { viewModel.editSchoolId },
            set: { viewModel.editSchoolId = $0 }
          )) {
            Text("General / Not School-Specific").tag(nil as String?)
            ForEach(viewModel.schools, id: \.id) { school in
              Text(school.name).tag(school.id as String?)
            }
          }
          .accessibilityLabel("School")

          TextField("Description", text: $viewModel.editDescription, axis: .vertical)
            .lineLimit(3...6)
            .accessibilityLabel("Description")
            .onChange(of: viewModel.editDescription) { _, newValue in
              if newValue.count > 500 {
                viewModel.editDescription = String(newValue.prefix(500))
              }
            }
          if viewModel.editDescription.count >= 500 {
            Text("\(viewModel.editDescription.count)/500 characters")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } header: {
          Text("Optional")
        }
      }
      .navigationTitle("Edit Document")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            viewModel.showEditSheet = false
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task { await viewModel.saveEdit() }
          }
          .disabled(!viewModel.canSaveEdit || viewModel.isSaving)
        }
      }
    }
  }
}
