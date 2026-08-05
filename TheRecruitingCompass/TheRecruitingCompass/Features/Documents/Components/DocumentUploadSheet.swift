import SwiftUI
import UniformTypeIdentifiers

struct DocumentUploadSheet: View {
  @Bindable var viewModel: DocumentsListViewModel
  @State private var showFilePicker = false

  private static let allowedTypes: [UTType] = [
    .pdf, .plainText, .movie, .mpeg4Movie, .quickTimeMovie,
    .commaSeparatedText, .spreadsheet, .data
  ]

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Document Type", selection: Binding(
            get: { viewModel.uploadType },
            set: { viewModel.uploadType = $0 }
          )) {
            Text("Select Type").tag(nil as DocumentType?)
            ForEach(DocumentType.allCases, id: \.self) { type in
              Text("\(type.typeEmoji) \(type.label)").tag(type as DocumentType?)
            }
          }
          .accessibilityLabel(String(localized: "Document type"))

          TextField("Title", text: $viewModel.uploadTitle, prompt: Text("e.g., Freshman Highlights 2025"))
            .accessibilityLabel(String(localized: "Document title"))
        } header: {
          Text("Required")
        }

        Section {
          Picker("School", selection: $viewModel.uploadSchoolId) {
            Text("General / Not School-Specific").tag(nil as String?)
            ForEach(viewModel.schools, id: \.id) { school in
              Text(school.name).tag(school.id as String?)
            }
          }
          .accessibilityLabel(String(localized: "School"))

          Stepper("Version: \(viewModel.uploadVersion)", value: $viewModel.uploadVersion, in: 1...100)
            .accessibilityLabel(String(localized: "Version number"))
            .accessibilityValue("\(viewModel.uploadVersion)")

          TextField("Description", text: $viewModel.uploadDescription, axis: .vertical)
            .lineLimit(3...6)
            .accessibilityLabel(String(localized: "Description"))
        } header: {
          Text("Optional")
        }

        Section {
          Button {
            showFilePicker = true
          } label: {
            HStack {
              Image(systemName: "doc.badge.plus")
              Text(viewModel.selectedFileName ?? "Select file")
                .foregroundStyle(viewModel.selectedFileURL == nil ? .secondary : .primary)
            }
          }
          .disabled(viewModel.uploadType == nil)
          .accessibilityLabel(String(localized: "Select file"))
          .accessibilityHint(viewModel.uploadType == nil ? "Select document type first" : "Opens file picker")

          if let type = viewModel.uploadType {
            Text("Allowed: \(type.allowedExtensions.joined(separator: ", "))")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          if viewModel.isUploading {
            VStack(alignment: .leading, spacing: 8) {
              if viewModel.uploadProgress > 0 && viewModel.uploadProgress < 1 {
                ProgressView(value: viewModel.uploadProgress)
                  .tint(.blue)
              } else {
                ProgressView()
              }
              Text(viewModel.uploadProgress > 0 && viewModel.uploadProgress < 1
                ? "\(Int(viewModel.uploadProgress * 100))%"
                : "Uploading...")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          if let uploadError = viewModel.uploadError {
            Text(uploadError)
              .font(.caption)
              .foregroundStyle(.red)
          }
        } header: {
          Text("File")
        }
      }
      .navigationTitle("Upload Document")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            viewModel.dismissUploadForm()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Upload") {
            Task { await viewModel.uploadDocument() }
          }
          .disabled(!isUploadValid || viewModel.isUploading)
        }
      }
      .fileImporter(
        isPresented: $showFilePicker,
        allowedContentTypes: Self.allowedTypes,
        allowsMultipleSelection: false
      ) { result in
        switch result {
        case .success(let urls):
          if let url = urls.first {
            _ = url.startAccessingSecurityScopedResource()
            viewModel.setSelectedFile(url)
          }
        case .failure:
          viewModel.uploadError = "Failed to select file."
        }
      }
    }
  }

  private var isUploadValid: Bool {
    viewModel.uploadType != nil
    && !viewModel.uploadTitle.trimmingCharacters(in: .whitespaces).isEmpty
    && viewModel.selectedFileURL != nil
  }
}
