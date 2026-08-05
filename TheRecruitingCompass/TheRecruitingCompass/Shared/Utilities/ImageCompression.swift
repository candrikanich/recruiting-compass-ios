import UIKit

/// Downsamples and JPEG-encodes an image off the caller's isolation context.
/// `UIGraphicsImageRenderer` and `jpegData` are CPU-bound and, on a full-resolution
/// photo-picker image, expensive enough (300-800ms) to visibly freeze the UI if run
/// on the main actor — call this from a background context (e.g. `Task.detached`).
enum ImageCompression {
  static func downsampledJPEGData(
    from image: UIImage,
    maxDimension: CGFloat = 1024,
    maxBytes: Int = 1_000_000
  ) -> Data? {
    let size = image.size
    let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
    let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

    let renderer = UIGraphicsImageRenderer(size: targetSize)
    let resized = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }

    // Try progressively lower quality until under the size cap.
    for quality in stride(from: 0.8, through: 0.3, by: -0.1) {
      if let data = resized.jpegData(compressionQuality: quality), data.count <= maxBytes {
        return data
      }
    }
    return resized.jpegData(compressionQuality: 0.3)
  }
}
