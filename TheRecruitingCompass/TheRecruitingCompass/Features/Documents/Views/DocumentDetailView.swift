import SwiftUI
import UniformTypeIdentifiers

struct DocumentDetailView: View {
  private enum Layout {
    static let cardSpacing: CGFloat = 16
    static let errorSpacing: CGFloat = 16
  }

  @State private var viewModel: DocumentDetailViewModel
  @State private var showFileImporter = false
  @Environment(\.dismiss) private var dismiss

  init(
    documentId: String,
    documentsService: (any DocumentsManaging)? = nil,
    schoolsService: (any SchoolsManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    familyManager: FamilyManager? = nil
  ) {
    _viewModel = State(initialValue: DocumentDetailViewModel(
      documentId: documentId,
      documentsService: documentsService,
      schoolsService: schoolsService,
      authManager: authManager,
      familyManager: familyManager
    ))
  }

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.document == nil {
        loadingState
      } else if viewModel.document == nil && viewModel.isNotFound {
        notFoundView
      } else if let errorMessage = viewModel.error, viewModel.document == nil {
        errorState(message: errorMessage)
      } else if let document = viewModel.document {
        documentContent(document)
      }
    }
    .navigationTitle(documentTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar { toolbarContent }
    .task {
      await viewModel.loadDocument()
      await viewModel.loadSchools()
    }
    .refreshable {
      await viewModel.loadDocument()
    }
    .sheet(isPresented: $viewModel.showEditSheet) {
      DocumentEditSheet(viewModel: viewModel)
    }
    .sheet(isPresented: $viewModel.showShareModal) {
      DocumentShareSheet(viewModel: viewModel)
    }
    .confirmationDialog("Delete Document", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
      Button("Delete", role: .destructive) { Task { await viewModel.deleteDocument() } }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Are you sure you want to delete this document? This action cannot be undone.")
    }
    .confirmationDialog("Restore Version", isPresented: $viewModel.showRestoreConfirmation, titleVisibility: .visible) {
      Button("Restore") { Task { await viewModel.restoreVersion() } }
      Button("Cancel", role: .cancel) {
        viewModel.versionToRestore = nil
      }
    } message: {
      Text("Restore this version? The current version will be marked as archived.")
    }
    .alert("Error", isPresented: Binding(
      get: { viewModel.error != nil && viewModel.document != nil },
      set: { if !$0 { viewModel.clearError() } }
    )) {
      Button("Retry") { Task { await viewModel.loadDocument() } }
      Button("OK", role: .cancel) { viewModel.clearError() }
    } message: {
      Text(viewModel.error ?? "")
    }
    .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
      if shouldDismiss { dismiss() }
    }
    .fileImporter(
      isPresented: $showFileImporter,
      allowedContentTypes: utTypes(for: viewModel.document?.type),
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          _ = url.startAccessingSecurityScopedResource()
          Task { await viewModel.uploadNewVersion(file: url) }
        }
      case .failure:
        viewModel.error = "Failed to select file."
      }
    }
  }

  private func utTypes(for type: DocumentType?) -> [UTType] {
    [
      .pdf, .plainText, .movie, .mpeg4Movie, .quickTimeMovie,
      .commaSeparatedText, .spreadsheet, .data
    ]
  }

  private var documentTitle: String {
    viewModel.document?.title ?? "Document"
  }

  // MARK: - Loading / Empty / Error

  private var loadingState: some View {
    ContentUnavailableView {
      ProgressView()
    } description: {
      Text("Loading document...")
    }
  }

  private var notFoundView: some View {
    ContentUnavailableView {
      Label("Document not found", systemImage: "doc.badge.gearshape")
    } description: {
      Text("This document may have been deleted or moved.")
    } actions: {
      Button("Return to Documents") { dismiss() }
        .accessibilityLabel("Return to Documents")
    }
  }

  private func errorState(message: String) -> some View {
    VStack(spacing: Layout.errorSpacing) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text(message)
        .font(.body)
        .multilineTextAlignment(.center)
      Button("Retry") { Task { await viewModel.loadDocument() } }
        .buttonStyle(.bordered)
        .accessibilityLabel("Retry loading document")
    }
    .padding()
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button("Back") { dismiss() }
        .accessibilityLabel("Back to Documents")
    }
  }

  // MARK: - Content

  private func documentContent(_ document: Document) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Layout.cardSpacing) {
        if viewModel.error != nil {
          errorBanner
        }
        documentHeaderCard(document)
        metadataGrid(document)
        previewCard(document)
        versionHistoryCard(document)
      }
      .padding()
    }
  }

  private var errorBanner: some View {
    HStack {
      Text(viewModel.error ?? "")
        .font(.caption)
        .foregroundStyle(.white)
      Spacer()
      Button("Retry") { Task { await viewModel.loadDocument() } }
        .font(.caption)
        .foregroundStyle(.white)
    }
    .padding()
    .background(Color.errorRed)
    .cornerRadius(8)
  }

  private func documentHeaderCard(_ document: Document) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          Text("\(document.typeEmoji) \(document.typeLabel)")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentBlue.opacity(0.2))
            .foregroundStyle(.primary)
            .cornerRadius(6)
          Text(document.title)
            .font(.title2)
            .fontWeight(.bold)
          if let desc = document.description, !desc.isEmpty {
            Text(desc)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()
      }
      HStack(spacing: 12) {
        Button {
          viewModel.openEditForm()
        } label: {
          Label("Edit", systemImage: "pencil")
            .font(.subheadline.weight(.medium))
            .frame(minWidth: 88, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentBlue)
        .accessibilityLabel("Edit document metadata")

        Button {
          viewModel.presentShareModal()
        } label: {
          Label("Share", systemImage: "square.and.arrow.up")
            .font(.subheadline.weight(.medium))
            .frame(minWidth: 88, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.primaryGreen)
        .accessibilityLabel("Share document with schools")

        Button(role: .destructive) {
          viewModel.confirmDelete()
        } label: {
          Label("Delete", systemImage: "trash")
            .font(.subheadline.weight(.medium))
            .frame(minWidth: 88, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.errorRed)
        .accessibilityLabel("Delete document")
        .accessibilityHint("This action cannot be undone")
      }
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(12)
  }

  private func metadataGrid(_ document: Document) -> some View {
    LazyVGrid(columns: [
      GridItem(.flexible()),
      GridItem(.flexible())
    ], spacing: 12) {
      metadataItem(label: "Version", value: "v\(document.version)")
      metadataItem(label: "School", value: viewModel.schoolName(for: document.schoolId))
      metadataItem(label: "Uploaded", value: document.displayDate)
      metadataItem(label: "File Type", value: document.fileType ?? "Unknown")
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(12)
  }

  private func metadataItem(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.subheadline)
        .fontWeight(.medium)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func previewCard(_ document: Document) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Preview")
        .font(.headline)
      DocumentPreviewView(document: document)
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(12)
  }

  private func versionHistoryCard(_ document: Document) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Version History")
        .font(.headline)
      if viewModel.versions.isEmpty {
        Text("No previous versions")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        ForEach(viewModel.versions) { version in
          versionRow(version)
        }
      }
      Button {
        showFileImporter = true
      } label: {
        Label("Upload New Version", systemImage: "plus")
          .font(.subheadline.weight(.medium))
          .frame(maxWidth: .infinity, minHeight: 44)
      }
      .accessibilityLabel("Upload New Version")
      .accessibilityHint("Select a file to add a new version")
      .buttonStyle(.borderedProminent)
      .disabled(viewModel.isUploadingNewVersion)
      .overlay {
        if viewModel.isUploadingNewVersion {
          ProgressView()
        }
      }
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(12)
  }

  private func versionRow(_ version: DocumentVersion) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text("v\(version.version)")
            .font(.subheadline)
            .fontWeight(.semibold)
          if version.isCurrent {
            Text("Current")
              .font(.caption2)
              .fontWeight(.semibold)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.accentBlue.opacity(0.2))
              .cornerRadius(4)
          }
        }
        Text(version.displayDate)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      HStack(spacing: 8) {
        if let url = URL(string: version.fileUrl) {
          Link(destination: url) {
            Text("View")
              .font(.caption)
          }
          .buttonStyle(.bordered)
        }
        if !version.isCurrent {
          Button("Restore") {
            viewModel.confirmRestore(version: version)
          }
          .font(.caption)
          .buttonStyle(.bordered)
          .frame(minHeight: 44)
          .contentShape(Rectangle())
          .accessibilityLabel("Restore version \(version.version)")
          .accessibilityHint("Restores this version as the current document")
        }
      }
    }
    .padding(.vertical, 8)
  }
}
