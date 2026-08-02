import SwiftUI

// MARK: - Layout Constants

private enum DocumentViewerLayout {
  static let overlayOpacity: Double = 0.8
  static let toolbarAnimationDuration: Double = 0.2
  static let dismissDragThreshold: CGFloat = 150
  static let toolbarButtonMinSize: CGFloat = 44
}

// MARK: - Toolbar Icon Button

private struct DocumentViewerIconButton: View {
  let systemName: String
  let accessibilityLabel: String
  let accessibilityIdentifier: String?
  let isEnabled: Bool
  let action: () -> Void

  init(
    systemName: String,
    accessibilityLabel: String,
    accessibilityIdentifier: String? = nil,
    isEnabled: Bool = true,
    action: @escaping () -> Void
  ) {
    self.systemName = systemName
    self.accessibilityLabel = accessibilityLabel
    self.accessibilityIdentifier = accessibilityIdentifier
    self.isEnabled = isEnabled
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.title2)
        .foregroundStyle(isEnabled ? .white : .gray)
        .frame(minWidth: DocumentViewerLayout.toolbarButtonMinSize, minHeight: DocumentViewerLayout.toolbarButtonMinSize)
        .contentShape(Rectangle())
    }
    .disabled(!isEnabled)
    .accessibilityLabel(accessibilityLabel)
    .modifier(OptionalAccessibilityIdentifier(identifier: accessibilityIdentifier))
  }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
  let identifier: String?

  func body(content: Content) -> some View {
    if let id = identifier, !id.isEmpty {
      content.accessibilityIdentifier(id)
    } else {
      content
    }
  }
}

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
          .animation(.easeInOut(duration: DocumentViewerLayout.toolbarAnimationDuration), value: viewModel.isToolbarVisible)
      }

      if viewModel.collection != nil && viewModel.isToolbarVisible {
        bottomNavigationBar
          .animation(.easeInOut(duration: DocumentViewerLayout.toolbarAnimationDuration), value: viewModel.isToolbarVisible)
      }

      if viewModel.isLoading {
        loadingOverlay
      }

      if viewModel.errorMessage != nil {
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
          if value.translation.height > DocumentViewerLayout.dismissDragThreshold {
            dismiss()
          } else {
            withAnimation(.easeOut(duration: DocumentViewerLayout.toolbarAnimationDuration)) {
              dragOffset = 0
            }
          }
        }
    )
    .onTapGesture {
      viewModel.cancelToolbarAutoHide()
      withAnimation(.easeInOut(duration: DocumentViewerLayout.toolbarAnimationDuration)) {
        viewModel.isToolbarVisible.toggle()
      }
      if viewModel.isToolbarVisible, viewModel.document?.isVideo == true {
        viewModel.scheduleToolbarAutoHide()
      }
    }
    .onChange(of: viewModel.document?.id) { _, _ in
      viewModel.cancelToolbarAutoHide()
      viewModel.isToolbarVisible = true
      if viewModel.document?.isVideo == true {
        viewModel.scheduleToolbarAutoHide()
      }
    }
    .onAppear {
      if viewModel.isToolbarVisible, viewModel.document?.isVideo == true {
        viewModel.scheduleToolbarAutoHide()
      }
    }
    .statusBarHidden(!viewModel.isToolbarVisible)
    .accessibilityIdentifier("document-viewer-view")
    .sheet(
      isPresented: $viewModel.isShareSheetPresented,
      onDismiss: { viewModel.downloadedFileURL = nil }
    ) {
      if !viewModel.shareItems.isEmpty {
        ShareSheet(items: viewModel.shareItems)
      }
    }
  }

  @ViewBuilder
  private var contentArea: some View {
    Group {
      if let document = viewModel.document {
        DocumentPreviewView(document: document, isFullscreen: true)
          .offset(y: dragOffset * 0.3)
          .contentShape(Rectangle())
          .simultaneousGesture(collectionSwipeGesture)
      } else if viewModel.errorMessage == nil && !viewModel.isLoading {
        ContentUnavailableView {
          Label("Document not found", systemImage: "doc")
        } description: {
          Text("The document could not be loaded")
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var collectionSwipeGesture: some Gesture {
    DragGesture(minimumDistance: 50)
      .onEnded { value in
        guard viewModel.collection != nil else { return }
        if value.translation.width < -50, viewModel.hasNext {
          viewModel.nextDocument()
        } else if value.translation.width > 50, viewModel.hasPrevious {
          viewModel.previousDocument()
        }
      }
  }

  @ViewBuilder
  private var topToolbar: some View {
    VStack(spacing: 0) {
      HStack {
        DocumentViewerIconButton(
          systemName: "xmark.circle.fill",
          accessibilityLabel: "Close document viewer",
          accessibilityIdentifier: "document-viewer-close",
          action: { dismiss() }
        )

        Spacer()

        Text(viewModel.document?.title ?? "Document")
          .font(.headline)
          .foregroundStyle(.white)
          .lineLimit(1)
          .truncationMode(.tail)

        Spacer()

        HStack(spacing: 16) {
          DocumentViewerIconButton(
            systemName: "square.and.arrow.up",
            accessibilityLabel: "Share document",
            accessibilityIdentifier: "document-viewer-share",
            isEnabled: !viewModel.shareItems.isEmpty,
            action: { viewModel.shareDocument() }
          )

          DocumentViewerIconButton(
            systemName: "arrow.down.circle",
            accessibilityLabel: "Download document to device",
            accessibilityIdentifier: "document-viewer-download",
            isEnabled: viewModel.document != nil && !viewModel.isDownloading,
            action: { Task { await viewModel.downloadDocument() } }
          )
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)

      if viewModel.isDownloading {
        VStack(spacing: 4) {
          ProgressView(value: viewModel.downloadProgress, total: 1)
            .progressViewStyle(.linear)
            .tint(.white)
          if viewModel.downloadProgress > 0, viewModel.downloadProgress < 1 {
            Text("\(Int(viewModel.downloadProgress * 100))%")
              .font(.caption)
              .foregroundStyle(.white)
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
      }

      Spacer()
    }
    .background(Color.black.opacity(DocumentViewerLayout.overlayOpacity))
    .transition(.opacity)
  }

  @ViewBuilder
  private var bottomNavigationBar: some View {
    if let coll = viewModel.collection {
      VStack {
        Spacer()
        HStack {
          DocumentViewerIconButton(
            systemName: "chevron.left",
            accessibilityLabel: "View previous document",
            isEnabled: viewModel.hasPrevious,
            action: { viewModel.previousDocument() }
          )

          Spacer()

          Text("\(viewModel.currentIndex + 1) of \(coll.documents.count)")
            .font(.subheadline)
            .foregroundStyle(.white)
            .accessibilityLabel("Document \(viewModel.currentIndex + 1) of \(coll.documents.count)")

          Spacer()

          DocumentViewerIconButton(
            systemName: "chevron.right",
            accessibilityLabel: "View next document",
            isEnabled: viewModel.hasNext,
            action: { viewModel.nextDocument() }
          )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.black.opacity(DocumentViewerLayout.overlayOpacity))
      }
      .transition(.opacity)
    }
  }

  @ViewBuilder
  private var loadingOverlay: some View {
    ZStack {
      Color.black.opacity(0.6)
        .ignoresSafeArea()
      ProgressView()
        .scaleEffect(1.2)
        .tint(.white)
    }
  }

  @ViewBuilder
  private var errorOverlay: some View {
    ZStack {
      Color.black.opacity(DocumentViewerLayout.overlayOpacity)
        .ignoresSafeArea()

      VStack(spacing: 20) {
        Image(systemName: "exclamationmark.triangle")
          .font(.largeTitle)
          .foregroundStyle(.white)
          .accessibilityHidden(true)

        Text(viewModel.errorMessage ?? "Something went wrong")
          .font(.subheadline)
          .foregroundStyle(.white)
          .multilineTextAlignment(.center)
          .padding(.horizontal)

        Button("Retry") {
          viewModel.retryLoad()
        }
        .buttonStyle(.borderedProminent)
        .tint(.white)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Retry loading document")

        Button("Close") {
          dismiss()
        }
        .foregroundStyle(.white)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Close document viewer")
      }
      .padding(32)
    }
  }
}
