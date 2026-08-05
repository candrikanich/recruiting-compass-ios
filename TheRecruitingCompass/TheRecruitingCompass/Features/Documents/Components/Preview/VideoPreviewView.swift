import SwiftUI
import AVFoundation
import AVKit

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
        .clipShape(.rect(cornerRadius: 8))
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
