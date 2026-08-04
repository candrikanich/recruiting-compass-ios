import SwiftUI

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
        .clipShape(.rect(cornerRadius: 8))
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
