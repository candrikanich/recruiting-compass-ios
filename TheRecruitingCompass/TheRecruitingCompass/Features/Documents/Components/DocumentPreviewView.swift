import SwiftUI
import AVKit
import PDFKit

struct DocumentPreviewView: View {
  let document: Document

  var body: some View {
    Group {
      if document.isVideo {
        VideoPreviewView(url: document.fileUrl)
      } else if document.isImage {
        ImagePreviewView(url: document.fileUrl)
      } else if document.isPDF {
        PDFPreviewView(url: document.fileUrl)
      } else {
        DownloadFallbackView(url: document.fileUrl, title: document.title)
      }
    }
  }
}

// MARK: - Video Preview

struct VideoPreviewView: View {
  let url: String

  var body: some View {
    if let videoURL = URL(string: url) {
      VideoPlayer(player: AVPlayer(url: videoURL))
        .aspectRatio(16/9, contentMode: .fit)
        .cornerRadius(8)
    } else {
      previewUnavailable
    }
  }

  private var previewUnavailable: some View {
    VStack(spacing: 8) {
      Image(systemName: "video.slash")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("Preview unavailable")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(32)
  }
}

// MARK: - Image Preview

struct ImagePreviewView: View {
  let url: String

  var body: some View {
    if let imageURL = URL(string: url) {
      AsyncImage(url: imageURL) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFit()
        case .failure:
          previewUnavailable
        case .empty:
          ProgressView()
            .frame(maxWidth: .infinity)
            .padding(32)
        @unknown default:
          previewUnavailable
        }
      }
      .cornerRadius(8)
    } else {
      previewUnavailable
    }
  }

  private var previewUnavailable: some View {
    VStack(spacing: 8) {
      Image(systemName: "photo")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("Preview unavailable")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(32)
  }
}

// MARK: - PDF Preview

struct PDFPreviewView: View {
  let url: String

  var body: some View {
    if let pdfURL = URL(string: url) {
      PDFKitRepresentable(url: pdfURL)
        .frame(minHeight: 400)
        .cornerRadius(8)
    } else {
      previewUnavailable
    }
  }

  private var previewUnavailable: some View {
    VStack(spacing: 8) {
      Image(systemName: "doc")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("Preview unavailable")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(32)
  }
}

struct PDFKitRepresentable: UIViewRepresentable {
  let url: URL

  func makeUIView(context: Context) -> PDFView {
    let view = PDFView()
    view.autoScales = true
    view.displayMode = .singlePageContinuous
    if let doc = PDFDocument(url: url) {
      view.document = doc
    }
    return view
  }

  func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Download Fallback

struct DownloadFallbackView: View {
  let url: String
  let title: String

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "arrow.down.circle")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("Preview not available for this file type")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      if let downloadURL = URL(string: url) {
        Link(destination: downloadURL) {
          Label("Download \(title)", systemImage: "arrow.down")
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Download \(title)")
        .accessibilityHint("Opens the file in the default app")
      }
    }
    .frame(maxWidth: .infinity)
    .padding(32)
  }
}
