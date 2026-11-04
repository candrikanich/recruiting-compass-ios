import SwiftUI

struct DocumentPreviewView: View {
  private enum Resolution {
    case resolving
    case ready(String)
    case unavailable
  }

  let document: Document
  var isFullscreen: Bool = false
  var urlResolver: any DocumentURLResolving = DocumentURLResolver()

  @State private var resolution: Resolution = .resolving

  var body: some View {
    Group {
      switch resolution {
      case .resolving:
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      case .unavailable:
        PreviewUnavailableView(icon: "doc", message: "Preview unavailable")
      case .ready(let url):
        preview(url: url)
      }
    }
    .task(id: document.fileUrl) {
      resolution = .resolving
      do {
        resolution = .ready(try await urlResolver.openableURL(for: document.fileUrl).absoluteString)
      } catch {
        resolution = .unavailable
      }
    }
  }

  @ViewBuilder
  private func preview(url: String) -> some View {
    if document.isVideo {
      VideoPreviewView(url: url, isFullscreen: isFullscreen)
    } else if document.isImage {
      ImagePreviewView(url: url, isFullscreen: isFullscreen, title: document.title)
    } else if document.isPDF {
      PDFPreviewView(url: url, isFullscreen: isFullscreen)
    } else {
      DownloadFallbackView(url: url, title: document.title)
    }
  }
}
