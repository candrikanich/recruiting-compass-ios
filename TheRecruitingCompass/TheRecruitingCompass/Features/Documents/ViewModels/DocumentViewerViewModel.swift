import Foundation
import Observation
import UIKit

// MARK: - DocumentViewerViewModel

@Observable
@MainActor
final class DocumentViewerViewModel {

  // MARK: - State

  var document: Document?
  var isLoading = false
  var error: String?
  var isToolbarVisible = true
  var isShareSheetPresented = false
  var downloadProgress: Double = 0

  var collection: DocumentCollection?
  var currentIndex: Int = 0

  private var toolbarAutoHideTask: Task<Void, Never>?

  // MARK: - Computed

  var shareableURL: URL? {
    guard let fileUrl = document?.fileUrl else { return nil }
    return URL(string: fileUrl)
  }

  /// Last downloaded file URL (for sharing after download)
  var downloadedFileURL: URL?

  /// Items to share (local file after download, or remote URL)
  var shareItems: [Any] {
    if let local = downloadedFileURL { return [local] }
    if let url = shareableURL { return [url] }
    return []
  }

  // MARK: - Dependencies

  private let documentsService: any DocumentsManaging

  // MARK: - Init

  init(
    document: Document? = nil,
    collection: DocumentCollection? = nil,
    documentsService: (any DocumentsManaging)? = nil
  ) {
    self.document = document
    self.collection = collection
    self.documentsService = documentsService ?? DocumentsServiceImpl()

    if let coll = collection {
      currentIndex = coll.currentIndex
      if self.document == nil {
        self.document = coll.currentDocument
      }
    }
    isLoading = false
  }

  // MARK: - Load

  func loadDocument(id: String) async {
    isLoading = true
    error = nil
    defer { isLoading = false }

    do {
      document = try await documentsService.fetchDocument(id: id)
    } catch {
      self.error = "Unable to load document. Check your connection."
    }
  }

  func retryLoad() {
    error = nil
    if let id = document?.id {
      Task { await loadDocument(id: id) }
    } else if let coll = collection {
      document = coll.currentDocument
    }
  }

  // MARK: - Share

  func shareDocument() {
    guard canShare else { return }
    presentShareSheet()
  }

  private var canShare: Bool {
    shareableURL != nil || downloadedFileURL != nil
  }

  private func presentShareSheet() {
    isShareSheetPresented = true
  }

  // MARK: - Toolbar Auto-Hide (Video)

  func cancelToolbarAutoHide() {
    toolbarAutoHideTask?.cancel()
    toolbarAutoHideTask = nil
  }

  func scheduleToolbarAutoHide() {
    guard document?.isVideo == true else { return }
    cancelToolbarAutoHide()
    toolbarAutoHideTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(3))
      guard !Task.isCancelled else { return }
      isToolbarVisible = false
    }
  }

  // MARK: - Download

  func downloadDocument() async {
    guard let urlString = document?.fileUrl,
          let url = URL(string: urlString) else {
      error = "Invalid file URL"
      return
    }

    downloadProgress = 0

    do {
      let (tempURL, _) = try await URLSession.shared.download(from: url)
      let destURL = destinationURL(for: url)

      if FileManager.default.fileExists(atPath: destURL.path) {
        try FileManager.default.removeItem(at: destURL)
      }
      try FileManager.default.moveItem(at: tempURL, to: destURL)

      downloadProgress = 1
      downloadedFileURL = destURL
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      presentShareSheet()
    } catch {
      self.error = "Download failed. \(error.localizedDescription)"
    }

    downloadProgress = 0
  }

  private func destinationURL(for url: URL) -> URL {
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let baseName = document?.title ?? url.deletingPathExtension().lastPathComponent
    let ext = url.pathExtension.isEmpty ? "" : "." + url.pathExtension
    let fileName = baseName + ext
    let safeFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "document"
    return documentsURL.appendingPathComponent(safeFileName)
  }

  // MARK: - Collection Navigation

  func nextDocument() {
    guard let coll = collection, currentIndex < coll.documents.count - 1 else { return }
    currentIndex += 1
    document = coll.documents[currentIndex]
  }

  func previousDocument() {
    guard let coll = collection, currentIndex > 0 else { return }
    currentIndex -= 1
    document = coll.documents[currentIndex]
  }

  var hasNext: Bool {
    guard let c = collection else { return false }
    return currentIndex < c.documents.count - 1
  }

  var hasPrevious: Bool {
    collection != nil && currentIndex > 0
  }
}
