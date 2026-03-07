import SwiftUI

struct DocumentsListView: View {
  /// When false, content is used inside a parent NavigationStack (e.g. pushed from More menu).
  var embedInNavigationStack: Bool = true

  @State private var viewModel = DocumentsListViewModel()
  @State private var documentToDelete: Document?

  private var content: some View {
    Group {
      if viewModel.isLoading && viewModel.documents.isEmpty {
        loadingState
      } else {
        mainContent
      }
    }
    .navigationTitle("Documents")
    .navigationBarTitleDisplayMode(.inline)
    .refreshable {
      await viewModel.loadDocuments()
    }
    .task {
      await viewModel.loadDocuments()
      await viewModel.loadSchools()
    }
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button {
          viewModel.presentUploadForm()
        } label: {
          Image(systemName: "plus")
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Upload new document")
        .accessibilityHint("Opens form to upload a document")
      }
    }
    .sheet(isPresented: $viewModel.isUploadFormPresented) {
      DocumentUploadSheet(viewModel: viewModel)
    }
    .sheet(isPresented: $viewModel.isFilterSheetPresented) {
      DocumentFilterSheet(viewModel: viewModel)
    }
    .alert("Error", isPresented: Binding(
      get: { viewModel.error != nil },
      set: { if !$0 { viewModel.error = nil } }
    )) {
      Button("Retry") { Task { await viewModel.loadDocuments() } }
      Button("OK", role: .cancel) { viewModel.error = nil }
    } message: {
      Text(viewModel.error ?? "")
    }
    .fullScreenCover(item: Binding(
      get: { viewModel.documentToView },
      set: { viewModel.documentToView = $0 }
    )) { document in
      let docs = viewModel.sortedDocuments
      let idx = docs.firstIndex(where: { $0.id == document.id }) ?? 0
      let collection = DocumentCollection(documents: docs, currentIndex: idx)
      DocumentViewerView(viewModel: DocumentViewerViewModel(document: document, collection: collection))
    }
    .confirmationDialog("Delete Document", isPresented: Binding(
      get: { documentToDelete != nil },
      set: { if !$0 { documentToDelete = nil } }
    ), titleVisibility: .visible) {
      Button("Delete", role: .destructive) {
        if let doc = documentToDelete {
          Task { await viewModel.deleteDocument(id: doc.id) }
          documentToDelete = nil
        }
      }
      Button("Cancel", role: .cancel) { documentToDelete = nil }
    } message: {
      if let doc = documentToDelete {
        Text("Are you sure you want to delete \"\(doc.title)\"? This action cannot be undone.")
      }
    }
    .navigationDestination(for: String.self) { documentId in
      DocumentDetailView(documentId: documentId)
    }
    .onOpenURL { _ in }  // Required for navigationDestination with String
  }

  var body: some View {
    if embedInNavigationStack {
      NavigationStack {
        content
      }
    } else {
      content
    }
  }

  private var loadingState: some View {
    ContentUnavailableView {
      ProgressView()
    } description: {
      Text("Loading documents...")
    }
  }

  private var mainContent: some View {
    ScrollView {
      VStack(spacing: 16) {
        DocumentStatisticsCardsRow(statistics: viewModel.statistics)
          .padding(.vertical, 8)

        DocumentFilterBar(
          searchQuery: $viewModel.searchQuery,
          sortBy: $viewModel.sortBy,
          viewMode: $viewModel.viewMode,
          hasActiveFilters: viewModel.hasActiveFilters,
          activeFilterCount: viewModel.activeFilterCount,
          onFilterTapped: { viewModel.isFilterSheetPresented = true },
          onClearFilters: { viewModel.clearFilters() }
        )

        if viewModel.hasActiveFilters {
          DocumentActiveFilterChips(viewModel: viewModel)
            .padding(.vertical, 8)
        }

        if viewModel.documents.isEmpty {
          emptyState
        } else if viewModel.sortedDocuments.isEmpty {
          noResultsState
        } else {
          documentsContent
        }
      }
      .padding()
      .padding(.bottom, 80)
    }
    .overlay(alignment: .bottomTrailing) {
      uploadFAB
    }
    .overlay(alignment: .top) {
      if viewModel.error != nil {
        errorBanner
      }
    }
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("No documents yet", systemImage: "doc")
    } description: {
      Text("Upload videos, transcripts, and other documents to share with coaches")
    } actions: {
      Button("Upload Your First Document") {
        viewModel.presentUploadForm()
      }
      .buttonStyle(.borderedProminent)
      .accessibilityLabel("Upload your first document")
      .accessibilityHint("Opens the form to upload a document")
    }
  }

  private var noResultsState: some View {
    ContentUnavailableView.search(text: viewModel.searchQuery)
  }

  @ViewBuilder
  private var documentsContent: some View {
    if viewModel.viewMode == .grid {
      LazyVGrid(columns: [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
      ], spacing: 12) {
        ForEach(viewModel.sortedDocuments) { doc in
          DocumentCardView(
            document: doc,
            schoolName: viewModel.schoolName(for: doc.schoolId),
            onTap: { viewModel.presentViewer(for: doc) },
            onDelete: { documentToDelete = doc }
          )
          .contextMenu {
            Button(role: .destructive) {
              documentToDelete = doc
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
        }
      }
    } else {
      LazyVStack(spacing: 0) {
        ForEach(viewModel.sortedDocuments) { doc in
          DocumentListViewRow(
            document: doc,
            schoolName: viewModel.schoolName(for: doc.schoolId),
            onTap: { viewModel.presentViewer(for: doc) },
            onDelete: { documentToDelete = doc }
          )
        }
      }
    }
  }

  private var uploadFAB: some View {
    Button {
      viewModel.presentUploadForm()
    } label: {
      Image(systemName: "plus")
        .font(.title2)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
        .frame(width: 64, height: 64)
        .background(Color.blue)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    .accessibilityLabel("Upload new document")
    .accessibilityHint("Opens upload form")
  }

  private var errorBanner: some View {
    HStack {
      Text(viewModel.error ?? "")
        .font(.caption)
        .foregroundStyle(.white)
      Spacer()
      Button("Retry") {
        Task { await viewModel.loadDocuments() }
      }
      .font(.caption)
      .foregroundStyle(.white)
    }
    .padding()
    .background(Color.red)
    .cornerRadius(8)
    .padding()
  }
}
