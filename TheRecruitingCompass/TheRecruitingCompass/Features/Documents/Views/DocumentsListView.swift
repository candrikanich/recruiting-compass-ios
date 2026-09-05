import SwiftUI

struct DocumentsListView: View {
  @State private var viewModel = DocumentsListViewModel()
  @State private var documentToDelete: Document?
  @State private var realtimeService: DocumentsRealtimeService?
  @Environment(FamilyManager.self) private var familyManager

  private var showDeleteConfirmation: Binding<Bool> {
    Binding(
      get: { documentToDelete != nil },
      set: { if !$0 { documentToDelete = nil } }
    )
  }

  @ViewBuilder
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
    .searchable(text: $viewModel.searchQuery, prompt: "Search title or description...")
    .task {
      await viewModel.loadDocuments()
      await viewModel.loadSchools()
      await subscribeRealtime()
    }
    .onDisappear {
      let service = realtimeService
      realtimeService = nil
      Task { await service?.unsubscribe() }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          viewModel.presentUploadForm()
        } label: {
          Image(systemName: "plus")
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "Upload new document"))
        .accessibilityHint("Opens form to upload a document")
      }
    }
    .sheet(isPresented: $viewModel.isUploadFormPresented) {
      DocumentUploadSheet(viewModel: viewModel)
    }
    .sheet(isPresented: $viewModel.isFilterSheetPresented) {
      DocumentFilterSheet(viewModel: viewModel)
    }
    .alert("Error", isPresented: $viewModel.isShowingErrorAlert) {
      Button("Retry") { Task { await viewModel.loadDocuments() } }
      Button("OK", role: .cancel) { viewModel.errorMessage = nil }
    } message: {
      Text(viewModel.errorMessage ?? "")
    }
    .fullScreenCover(item: $viewModel.documentToView) { document in
      let docs = viewModel.sortedDocuments
      let idx = docs.firstIndex(where: { $0.id == document.id }) ?? 0
      let collection = DocumentCollection(documents: docs, currentIndex: idx)
      DocumentViewerView(viewModel: DocumentViewerViewModel(document: document, collection: collection))
    }
    .confirmationDialog("Delete Document", isPresented: showDeleteConfirmation, titleVisibility: .visible) {
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
    content
  }

  @ViewBuilder
  private var loadingState: some View {
    LoadingStateView(message: "Loading documents...")
  }

  @ViewBuilder
  private var mainContent: some View {
    ScrollView {
      VStack(spacing: 16) {
        DocumentStatisticsCardsRow(statistics: viewModel.statistics)
          .padding(.vertical, 8)

        DocumentFilterBar(
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
      if viewModel.errorMessage != nil {
        errorBanner
      }
    }
  }

  @ViewBuilder
  private var emptyState: some View {
    EmptyStateView(
      icon: "doc",
      title: String(localized: "No documents yet"),
      message: String(localized: "Upload videos, transcripts, and other documents to share with coaches"),
      actionTitle: String(localized: "Upload Your First Document"),
      actionHint: String(localized: "Opens the form to upload a document")
    ) {
      viewModel.presentUploadForm()
    }
  }

  @ViewBuilder
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

  @ViewBuilder
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
        .brandShadowSm()
    }
    .accessibilityLabel(String(localized: "Upload new document"))
    .accessibilityHint("Opens upload form")
  }

  @ViewBuilder
  private var errorBanner: some View {
    HStack {
      Text(viewModel.errorMessage ?? "")
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
    .clipShape(.rect(cornerRadius: 8))
    .padding()
  }

  private func subscribeRealtime() async {
    guard realtimeService == nil, let familyUnitId = familyManager.familyUnitId else { return }
    let service = DocumentsRealtimeService()
    realtimeService = service
    do {
      try await service.subscribe(familyUnitId: familyUnitId) { [viewModel] in
        Task { await viewModel.loadDocuments() }
      }
    } catch {
      // Non-fatal — page still works with pull-to-refresh
    }
  }
}
