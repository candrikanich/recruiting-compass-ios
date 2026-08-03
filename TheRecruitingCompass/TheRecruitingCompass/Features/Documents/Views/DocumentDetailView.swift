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
      } else if let errorMessage = viewModel.errorMessage, viewModel.document == nil {
        errorState(message: errorMessage)
      } else if let document = viewModel.document {
        documentContent(document)
      }
    }
    .navigationTitle(documentTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar { toolbarContent }
    .toolbar(.hidden, for: .tabBar)
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
    .alert("Error", isPresented: $viewModel.isShowingErrorAlert) {
      Button("Retry") { Task { await viewModel.loadDocument() } }
      Button("OK", role: .cancel) { viewModel.clearError() }
    } message: {
      Text(viewModel.errorMessage ?? "")
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
          let started = url.startAccessingSecurityScopedResource()
          Task {
            defer { if started { url.stopAccessingSecurityScopedResource() } }
            await viewModel.uploadNewVersion(file: url)
          }
        }
      case .failure:
        viewModel.errorMessage = "Failed to select file."
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

  @ViewBuilder
  private var loadingState: some View {
    ContentUnavailableView {
      ProgressView()
    } description: {
      Text("Loading document...")
    }
  }

  @ViewBuilder
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
      Button("Back to Documents") { dismiss() }
        .accessibilityLabel("Back to Documents")
    }
  }

  // MARK: - Content

  private func documentContent(_ document: Document) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Layout.cardSpacing) {
        if let error = viewModel.errorMessage {
          DocumentErrorBanner(error: error) {
            Task { await viewModel.loadDocument() }
          }
        }
        DocumentHeaderCard(
          document: document,
          onEdit: { viewModel.openEditForm() },
          onShare: { viewModel.presentShareModal() },
          onDelete: { viewModel.confirmDelete() }
        )
        DocumentMetadataGrid(
          document: document,
          schoolName: viewModel.schoolName(for: document.schoolId)
        )
        DocumentPreviewCard(document: document)
        DocumentVersionHistoryCard(
          versions: viewModel.versions,
          isUploadingNewVersion: viewModel.isUploadingNewVersion,
          uploadProgress: viewModel.uploadProgress,
          onUploadTap: { showFileImporter = true },
          onRestore: { viewModel.confirmRestore(version: $0) }
        )
      }
      .padding()
    }
  }
}
