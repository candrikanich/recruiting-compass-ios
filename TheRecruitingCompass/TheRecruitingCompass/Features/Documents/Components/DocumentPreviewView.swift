import SwiftUI
import AVFoundation
import AVKit
import PDFKit

// MARK: - Shared Preview Unavailable

struct PreviewUnavailableView: View {
  let icon: String
  let message: String

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(32)
  }
}

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

// MARK: - Video Preview

struct VideoPreviewView: View {
  let url: String
  var isFullscreen: Bool = false

  var body: some View {
    if let videoURL = URL(string: url) {
      VideoPreviewWithLoadingView(url: videoURL)
        .modifier(VideoPreviewLayoutModifier(isFullscreen: isFullscreen))
    } else {
      PreviewUnavailableView(icon: "video.slash", message: "Preview unavailable")
    }
  }
}

private struct VideoPreviewLayoutModifier: ViewModifier {
  let isFullscreen: Bool

  func body(content: Content) -> some View {
    if isFullscreen {
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      content
        .aspectRatio(16/9, contentMode: .fit)
        .cornerRadius(8)
    }
  }
}

struct VideoPreviewWithLoadingView: View {
  let url: URL
  @State private var isBuffering = true

  var body: some View {
    ZStack {
      VideoPlayerViewControllerRepresentable(url: url, isBuffering: $isBuffering)
      if isBuffering {
        ProgressView()
          .scaleEffect(1.2)
          .tint(.white)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.black.opacity(0.4))
      }
    }
  }
}

struct VideoPlayerViewControllerRepresentable: UIViewControllerRepresentable {
  let url: URL
  @Binding var isBuffering: Bool

  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let player = AVPlayer(url: url)
    let controller = AVPlayerViewController()
    controller.player = player
    context.coordinator.observeStatus(player: player)
    return controller
  }

  func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(isBuffering: $isBuffering)
  }

  final class Coordinator {
    @Binding var isBuffering: Bool
    private var statusObservation: NSKeyValueObservation?

    init(isBuffering: Binding<Bool>) {
      _isBuffering = isBuffering
    }

    deinit {
      statusObservation?.invalidate()
      statusObservation = nil
    }

    func observeStatus(player: AVPlayer) {
      let binding = _isBuffering
      statusObservation = player.currentItem?.observe(\.status, options: [.new]) { _, change in
        guard change.newValue == .readyToPlay else { return }
        Task { @MainActor in
          binding.wrappedValue = false
        }
      }
      if player.currentItem?.status == .readyToPlay {
        isBuffering = false
      }
    }
  }
}

// MARK: - Image Preview

struct ImagePreviewView: View {
  let url: String
  var isFullscreen: Bool = false

  var body: some View {
    if let imageURL = URL(string: url) {
      ZoomableImageView(url: imageURL)
        .modifier(ImagePreviewLayoutModifier(isFullscreen: isFullscreen))
    } else {
      PreviewUnavailableView(icon: "photo", message: "Preview unavailable")
    }
  }
}

private struct ImagePreviewLayoutModifier: ViewModifier {
  let isFullscreen: Bool

  func body(content: Content) -> some View {
    if isFullscreen {
      content
    } else {
      content
        .cornerRadius(8)
    }
  }
}

struct ZoomableImageView: View {
  let url: URL

  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero

  private let minScale: CGFloat = 1.0
  private let maxScale: CGFloat = 5.0

  var body: some View {
    AsyncImage(url: url) { phase in
      switch phase {
      case .success(let image):
        image
          .resizable()
          .scaledToFit()
          .scaleEffect(scale)
          .offset(offset)
          .gesture(
            MagnificationGesture()
              .onChanged { value in
                scale = min(max(lastScale * value, minScale), maxScale)
              }
              .onEnded { _ in
                lastScale = scale
              }
          )
          .simultaneousGesture(
            DragGesture()
              .onChanged { value in
                offset = CGSize(
                  width: lastOffset.width + value.translation.width,
                  height: lastOffset.height + value.translation.height
                )
              }
              .onEnded { _ in
                lastOffset = offset
              }
          )
          .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
              if scale > minScale {
                scale = minScale
                lastScale = minScale
                offset = .zero
                lastOffset = .zero
              } else {
                scale = 2.0
                lastScale = 2.0
              }
            }
          }
      case .failure:
        PreviewUnavailableView(icon: "photo", message: "Preview unavailable")
      case .empty:
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding(32)
      @unknown default:
        PreviewUnavailableView(icon: "photo", message: "Preview unavailable")
      }
    }
  }
}

// MARK: - PDF Preview

struct PDFPreviewView: View {
  let url: String
  var isFullscreen: Bool = false

  var body: some View {
    if let pdfURL = URL(string: url) {
      PDFKitRepresentable(url: pdfURL)
        .modifier(PDFPreviewLayoutModifier(isFullscreen: isFullscreen))
    } else {
      PreviewUnavailableView(icon: "doc", message: "Preview unavailable")
    }
  }
}

private struct PDFPreviewLayoutModifier: ViewModifier {
  let isFullscreen: Bool

  func body(content: Content) -> some View {
    if isFullscreen {
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      content
        .frame(minHeight: 400)
        .cornerRadius(8)
    }
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
          Label("Download to view", systemImage: "arrow.down")
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Download to view")
        .accessibilityHint("Opens the file in the default app")
      }
    }
    .frame(maxWidth: .infinity)
    .padding(32)
  }
}
