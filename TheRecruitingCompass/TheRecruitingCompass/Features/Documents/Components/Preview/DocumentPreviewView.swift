import SwiftUI

struct DocumentPreviewView: View {
  let document: Document
  var isFullscreen: Bool = false

  var body: some View {
    Group {
      if document.isVideo {
        VideoPreviewView(url: document.fileUrl, isFullscreen: isFullscreen)
      } else if document.isImage {
        ImagePreviewView(url: document.fileUrl, isFullscreen: isFullscreen)
      } else if document.isPDF {
        PDFPreviewView(url: document.fileUrl, isFullscreen: isFullscreen)
      } else {
        DownloadFallbackView(url: document.fileUrl, title: document.title)
      }
    }
  }
}
