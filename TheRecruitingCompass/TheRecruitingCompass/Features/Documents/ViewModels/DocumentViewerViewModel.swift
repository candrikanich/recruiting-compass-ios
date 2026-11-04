import Foundation
import Observation
import UIKit

// MARK: - Download Error Mapping

private func userFacingDownloadError(from error: Error) -> String {
  userFacingMessage(
    for: error,
    fallback: "Download failed. Check your connection.",
    secureConnectionFailed: "Secure connection failed. Please check your connection."
  )
}

private func userFacingLoadError(from error: Error) -> String {
  userFacingMessage(
    for: error,
    fallback: "Unable to load document. Check your connection.",
    notFound: "Document not found"
  )
}

// MARK: - DocumentViewerViewModel

@Observable
@MainActor
final class DocumentViewerViewModel {

  nonisolated deinit {}

  // MARK: - State

  var document: Document?
  var isLoading = false
  var errorMessage: String?
  var isToolbarVisible = true
  var isShareSheetPresented = false
  var downloadProgress: Double = 0
  var isDownloading = false
  var hapticImpactTrigger = 0

  var collection: DocumentCollection?
  var currentIndex: Int = 0

  private var toolbarAutoHideTask: Task<Void, Never>?
  private var downloadSession: URLSession?
  private var downloadDelegate: DocumentDownloadDelegate?

  // MARK: - Computed

  /// Last downloaded file URL (for sharing after download)
  var downloadedFileURL: URL?

  /// The downloaded file itself; a URL is never shared.
  var shareItems: [Any] {
    downloadedFileURL.map { [$0] } ?? []
  }

  // MARK: - Dependencies

  private let documentsService: any DocumentsManaging
  private let urlResolver: any DocumentURLResolving
  private let autoHideDelay: Duration
  private let isAssistiveTechnologyRunning: () -> Bool

  // MARK: - Init

  init(
    document: Document? = nil,
    collection: DocumentCollection? = nil,
    documentsService: (any DocumentsManaging)? = nil,
    urlResolver: any DocumentURLResolving = DocumentURLResolver(),
    autoHideDelay: Duration = .seconds(3),
    isAssistiveTechnologyRunning: @escaping () -> Bool = {
      UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
    }
  ) {
    self.autoHideDelay = autoHideDelay
    self.isAssistiveTechnologyRunning = isAssistiveTechnologyRunning
    self.document = document
    self.collection = collection
    self.documentsService = documentsService ?? DocumentsServiceImpl()
    self.urlResolver = urlResolver

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
    errorMessage = nil
    defer { isLoading = false }

    do {
      document = try await documentsService.fetchDocument(id: id)
    } catch {
      self.errorMessage = userFacingLoadError(from: error)
    }
  }

  func retryLoad() {
    errorMessage = nil
    if let id = document?.id {
      Task { await loadDocument(id: id) }
    } else if let coll = collection {
      document = coll.currentDocument
    }
  }

  // MARK: - File URL

  /// Signs (or passes through) the current document's `file_url` for a download. Resolved on every tap, so a
  /// retry always gets a fresh signature. A failure surfaces through `errorMessage`; it never degrades to
  /// the unsigned stored value, and a cancelled or superseded request stays silent.
  func resolveFileURL() async -> URL? {
    let requested = document?.fileUrl
    guard let requested else {
      errorMessage = "Invalid file URL"
      return nil
    }
    do {
      let url = try await urlResolver.openableURL(for: requested)
      return document?.fileUrl == requested ? url : nil
    } catch {
      guard document?.fileUrl == requested, !Self.isCancellation(error) else { return nil }
      if case DocumentURLError.notOpenable = error {
        errorMessage = "Invalid file URL"
      } else {
        errorMessage = userFacingMessage(for: error, fallback: "Unable to open document. Check your connection.")
      }
      return nil
    }
  }

  private static func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
  }

  // MARK: - Share

  /// Shares the file itself: downloads it through a freshly signed URL, then presents the share sheet.
  func shareDocument() async {
    if downloadedFileURL != nil {
      presentShareSheet()
    } else {
      await downloadDocument()
    }
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
    guard document?.isVideo == true, !isAssistiveTechnologyRunning() else { return }
    cancelToolbarAutoHide()
    toolbarAutoHideTask = Task { @MainActor in
      try? await Task.sleep(for: autoHideDelay)
      guard !Task.isCancelled else { return }
      isToolbarVisible = false
    }
  }

  func toggleToolbar() {
    cancelToolbarAutoHide()
    isToolbarVisible.toggle()
    if isToolbarVisible { scheduleToolbarAutoHide() }
  }

  // MARK: - Download

  func downloadDocument() async {
    guard let url = await resolveFileURL() else { return }

    let started = (id: document?.id, title: document?.title)
    downloadProgress = 0
    isDownloading = true
    defer {
      isDownloading = false
      downloadSession?.invalidateAndCancel()
      downloadSession = nil
      downloadDelegate = nil
    }

    let delegate = DocumentDownloadDelegate { [weak self] progress in
      guard let this = self else { return }
      Task { @MainActor in
        this.downloadProgress = progress
      }
    }
    downloadDelegate = delegate
    let config = URLSessionConfiguration.default
    let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    downloadSession = session

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      delegate.onComplete = { [weak self] result in
        guard let this = self else {
          continuation.resume()
          return
        }
        Task { @MainActor in
          // The user may have swiped to another document while this one downloaded.
          guard this.document?.id == started.id else {
            if case .success(let tempURL) = result { try? FileManager.default.removeItem(at: tempURL) }
            continuation.resume()
            return
          }
          switch result {
          case .success(let tempURL):
            do {
              let destURL = try this.destinationURL(for: url, title: started.title)
              try FileManager.default.moveItem(at: tempURL, to: destURL)
              this.downloadProgress = 1
              this.downloadedFileURL = destURL
              this.hapticImpactTrigger += 1
              this.presentShareSheet()
            } catch {
              this.errorMessage = userFacingDownloadError(from: error)
            }
          case .failure(let err):
            this.errorMessage = userFacingDownloadError(from: err)
          }
          continuation.resume()
        }
      }
      let task = session.downloadTask(with: url)
      task.resume()
    }
  }

  /// A fresh temp directory per download keeps the share sheet's file name equal to the title without
  /// colliding with earlier downloads, so nothing existing is ever removed.
  private func destinationURL(for url: URL, title: String?) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    guard let destination = DownloadDestination.url(
      title: title,
      fallbackBase: url.deletingPathExtension().lastPathComponent,
      pathExtension: url.pathExtension,
      in: directory
    ) else { throw DocumentURLError.notOpenable }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return destination
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

// MARK: - Document Download Delegate

private final class DocumentDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
  private let onProgress: @Sendable (Double) -> Void
  var onComplete: (@Sendable (Result<URL, Error>) -> Void)?
  private let lock = NSLock()
  private var hasCompleted = false

  init(onProgress: @escaping @Sendable (Double) -> Void) {
    self.onProgress = onProgress
  }

  private func finish(_ result: Result<URL, Error>) {
    lock.lock()
    defer { lock.unlock() }
    guard !hasCompleted else { return }
    hasCompleted = true
    onComplete?(result)
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard totalBytesExpectedToWrite > 0 else {
      onProgress(0)
      return
    }
    let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
    onProgress(min(max(progress, 0), 1))
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    do {
      if FileManager.default.fileExists(atPath: tempURL.path) {
        try FileManager.default.removeItem(at: tempURL)
      }
      try FileManager.default.copyItem(at: location, to: tempURL)
      finish(.success(tempURL))
    } catch {
      finish(.failure(error))
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error {
      finish(.failure(error))
    }
  }
}
