import Foundation
import Observation
import UIKit

// MARK: - Download Error Mapping

private func userFacingDownloadError(from error: Error) -> String {
  if let urlError = error as? URLError {
    switch urlError.code {
    case .notConnectedToInternet, .networkConnectionLost:
      return "No internet connection. Please check your connection."
    case .timedOut:
      return "Connection timed out. Please try again."
    case .serverCertificateHasBadDate, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
         .serverCertificateNotYetValid:
      return "Secure connection failed. Please check your connection."
    default:
      break
    }
  }
  return "Download failed. Check your connection."
}

private func userFacingLoadError(from error: Error) -> String {
  if let urlError = error as? URLError {
    switch urlError.code {
    case .notConnectedToInternet, .networkConnectionLost:
      return "No internet connection. Please check your connection."
    case .timedOut:
      return "Connection timed out. Please try again."
    default:
      break
    }
  }
  if (error as NSError).code == 404 {
    return "Document not found"
  }
  return "Unable to load document. Check your connection."
}

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
  var isDownloading = false

  var collection: DocumentCollection?
  var currentIndex: Int = 0

  private var toolbarAutoHideTask: Task<Void, Never>?
  private var downloadSession: URLSession?
  private var downloadDelegate: DocumentDownloadDelegate?

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
      self.error = userFacingLoadError(from: error)
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
          switch result {
          case .success(let tempURL):
            do {
              let destURL = this.destinationURL(for: url)
              if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
              }
              try FileManager.default.moveItem(at: tempURL, to: destURL)
              this.downloadProgress = 1
              this.downloadedFileURL = destURL
              UIImpactFeedbackGenerator(style: .medium).impactOccurred()
              this.presentShareSheet()
            } catch {
              this.error = userFacingDownloadError(from: error)
            }
          case .failure(let err):
            this.error = userFacingDownloadError(from: err)
          }
          continuation.resume()
        }
      }
      let task = session.downloadTask(with: url)
      task.resume()
    }
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
