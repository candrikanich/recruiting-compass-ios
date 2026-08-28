import SwiftUI

struct SchoolDocumentsSection: View {
  let schoolId: String

  @State private var viewModel: DocumentsListViewModel
  @State private var documentToUnshare: Document?

  init(schoolId: String) {
    self.schoolId = schoolId
    _viewModel = State(initialValue: DocumentsListViewModel(schoolScopeId: schoolId))
  }

  private var showUnshareConfirmation: Binding<Bool> {
    Binding(
      get: { documentToUnshare != nil },
      set: { if !$0 { documentToUnshare = nil } }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header

      if viewModel.isLoading && viewModel.documents.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding(.vertical, 24)
      } else if viewModel.sortedDocuments.isEmpty {
        DocumentsEmptyState()
      } else {
        documentsGrid
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowMd()
    .task {
      await viewModel.loadDocuments()
      await viewModel.loadSchools()
    }
    .sheet(isPresented: $viewModel.isUploadFormPresented) {
      DocumentUploadSheet(viewModel: viewModel)
    }
    .fullScreenCover(item: $viewModel.documentToView) { document in
      let docs = viewModel.sortedDocuments
      let idx = docs.firstIndex(where: { $0.id == document.id }) ?? 0
      let collection = DocumentCollection(documents: docs, currentIndex: idx)
      DocumentViewerView(viewModel: DocumentViewerViewModel(document: document, collection: collection))
    }
    .confirmationDialog(
      "Remove Document",
      isPresented: showUnshareConfirmation,
      titleVisibility: .visible
    ) {
      Button("Remove from School", role: .destructive) {
        if let doc = documentToUnshare {
          Task { await viewModel.unshareFromScope(id: doc.id) }
          documentToUnshare = nil
        }
      }
      Button("Cancel", role: .cancel) { documentToUnshare = nil }
    } message: {
      if let doc = documentToUnshare {
        Text("Remove \"\(doc.title)\" from this school? The document stays in your Documents library.")
      }
    }
    .alert("Error", isPresented: $viewModel.isShowingErrorAlert) {
      Button("OK", role: .cancel) { viewModel.errorMessage = nil }
    } message: {
      Text(viewModel.errorMessage ?? "")
    }
  }

  @ViewBuilder
  private var header: some View {
    HStack {
      Label("Documents", systemImage: "doc")
        .font(.headline)
        .foregroundStyle(.primary)

      Spacer()

      Button {
        viewModel.presentUploadForm()
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "plus")
          Text("Upload")
            .font(.subheadline)
        }
      }
      .accessibilityLabel(String(localized: "Upload document"))
      .accessibilityHint("Opens a form to upload a document for this school")
    }
  }

  @ViewBuilder
  private var documentsGrid: some View {
    LazyVGrid(columns: [
      GridItem(.flexible(), spacing: 12),
      GridItem(.flexible(), spacing: 12)
    ], spacing: 12) {
      ForEach(viewModel.sortedDocuments) { doc in
        DocumentCardView(
          document: doc,
          schoolName: viewModel.schoolName(for: doc.schoolId),
          onTap: { viewModel.presentViewer(for: doc) },
          onDelete: { documentToUnshare = doc }
        )
        .contextMenu {
          Button(role: .destructive) {
            documentToUnshare = doc
          } label: {
            Label("Remove from School", systemImage: "minus.circle")
          }
        }
      }
    }
  }
}

private struct DocumentsEmptyState: View {
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.text")
        .font(.largeTitle)
        .imageScale(.large)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("No Documents")
        .font(.headline)
        .foregroundStyle(.secondary)

      Text("Upload transcripts, highlights, and more to share with this school")
        .font(.subheadline)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "No documents"))
  }
}

#Preview {
  SchoolDocumentsSection(schoolId: "preview-school")
    .padding()
}
