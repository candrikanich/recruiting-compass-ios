import SwiftUI

struct DocumentViewerView: View {
  @Bindable var viewModel: DocumentViewerViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var dragOffset: CGFloat = 0

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      contentArea

      if viewModel.isToolbarVisible {
        topToolbar
          .animation(.easeInOut(duration: 0.2), value: viewModel.isToolbarVisible)
      }

      if viewModel.collection != nil && viewModel.isToolbarVisible {
        bottomNavigationBar
          .animation(.easeInOut(duration: 0.2), value: viewModel.isToolbarVisible)
      }

      if viewModel.isLoading {
        loadingOverlay
      }

      if viewModel.error != nil {
        errorOverlay
      }
    }
    .gesture(
      DragGesture()
        .onChanged { value in
          if value.translation.height > 0 {
            dragOffset = value.translation.height
          }
        }
        .onEnded { value in
          if value.translation.height > 150 {
            dismiss()
          } else {
            withAnimation(.easeOut(duration: 0.2)) {
              dragOffset = 0
            }
          }
        }
    )
    .onTapGesture {
      viewModel.cancelToolbarAutoHide()
      withAnimation(.easeInOut(duration: 0.2)) {
        viewModel.isToolbarVisible.toggle()
      }
      if viewModel.isToolbarVisible && viewModel.document?.isVideo == true {
        viewModel.scheduleToolbarAutoHide()
      }
    }
    .onChange(of: viewModel.document?.id) { _, _ in
      viewModel.cancelToolbarAutoHide()
      viewModel.isToolbarVisible = true
    }
    .onAppear {
      if viewModel.isToolbarVisible && viewModel.document?.isVideo == true {
        viewModel.scheduleToolbarAutoHide()
      }
    }
    .sheet(isPresented: Binding(
      get: { viewModel.isShareSheetPresented },
      set: {
        viewModel.isShareSheetPresented = $0
        if !$0 { viewModel.downloadedFileURL = nil }
      }
    )) {
      if !viewModel.shareItems.isEmpty {
        ShareSheet(items: viewModel.shareItems)
      }
    }
  }

  private var contentArea: some View {
    Group {
      if let document = viewModel.document {
        DocumentPreviewView(document: document)
          .offset(y: dragOffset * 0.3)
      } else if viewModel.error == nil && !viewModel.isLoading {
        ContentUnavailableView {
          Label("No document", systemImage: "doc")
        } description: {
          Text("Unable to load document")
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var topToolbar: some View {
    VStack {
      HStack {
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundStyle(.white)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Close document viewer")

        Spacer()

        Text(viewModel.document?.title ?? "Document")
          .font(.headline)
          .foregroundStyle(.white)
          .lineLimit(1)
          .truncationMode(.tail)

        Spacer()

        HStack(spacing: 16) {
          Button {
            viewModel.shareDocument()
          } label: {
            Image(systemName: "square.and.arrow.up")
              .font(.title2)
              .foregroundStyle(.white)
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .accessibilityLabel("Share document")
          .disabled(viewModel.shareableURL == nil)

          Button {
            Task { await viewModel.downloadDocument() }
          } label: {
            Image(systemName: "arrow.down.circle")
              .font(.title2)
              .foregroundStyle(.white)
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .accessibilityLabel("Download document to device")
          .disabled(viewModel.document == nil)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(Color.black.opacity(0.8))

      Spacer()
    }
    .transition(.opacity)
  }

  @ViewBuilder
  private var bottomNavigationBar: some View {
    if let coll = viewModel.collection {
      VStack {
        Spacer()
        HStack {
          Button {
            viewModel.previousDocument()
          } label: {
            Image(systemName: "chevron.left")
              .font(.title2)
              .foregroundStyle(viewModel.hasPrevious ? .white : .gray)
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .disabled(!viewModel.hasPrevious)
          .accessibilityLabel("View previous document")

          Spacer()

          Text("\(viewModel.currentIndex + 1) of \(coll.documents.count)")
            .font(.subheadline)
            .foregroundStyle(.white)
            .accessibilityLabel("Document \(viewModel.currentIndex + 1) of \(coll.documents.count)")

          Spacer()

          Button {
            viewModel.nextDocument()
          } label: {
            Image(systemName: "chevron.right")
              .font(.title2)
              .foregroundStyle(viewModel.hasNext ? .white : .gray)
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .disabled(!viewModel.hasNext)
          .accessibilityLabel("View next document")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
      }
      .transition(.opacity)
    }
  }

  private var loadingOverlay: some View {
    ZStack {
      Color.black.opacity(0.6)
        .ignoresSafeArea()
      ProgressView()
        .scaleEffect(1.2)
        .tint(.white)
    }
  }

  private var errorOverlay: some View {
    ZStack {
      Color.black.opacity(0.8)
        .ignoresSafeArea()

      VStack(spacing: 20) {
        Image(systemName: "exclamationmark.triangle")
          .font(.largeTitle)
          .foregroundStyle(.white)

        Text(viewModel.error ?? "Something went wrong")
          .font(.subheadline)
          .foregroundStyle(.white)
          .multilineTextAlignment(.center)
          .padding(.horizontal)

        Button("Retry") {
          viewModel.retryLoad()
        }
        .buttonStyle(.borderedProminent)
        .tint(.white)

        Button("Close") {
          dismiss()
        }
        .foregroundStyle(.white)
      }
      .padding(32)
    }
  }
}
