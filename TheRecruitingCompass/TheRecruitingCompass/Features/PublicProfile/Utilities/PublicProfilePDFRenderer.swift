import SwiftUI
import UIKit

/// Renders the coach-facing `PublicProfileCard` to a PDF so an athlete can share the exact same
/// profile as an offline file (share sheet, email attachment, AirDrop) instead of only a live link.
///
/// Uses SwiftUI `ImageRenderer` on the real card view — the card stays the single source of truth,
/// so the PDF cannot drift from what coaches see on the web. The whole card is drawn onto one
/// content-sized page (a profile reads top-to-bottom, like a one-page sheet). `ImageRenderer` must
/// run on the main actor.
enum PublicProfilePDFRenderer {

  /// Fixed layout width for the exported card, in points. Keeps the PDF a stable size regardless of
  /// the device the export runs on.
  static let contentWidth: CGFloat = 540

  /// Fetches the header photo (so it can be drawn synchronously), then renders the PDF.
  /// Photo-load failure is non-fatal — the card falls back to its placeholder.
  @MainActor
  static func renderWithPhoto(_ data: PublicProfileData) async -> Data? {
    let photo = await loadPhoto(data.photoUrl)
    return render(data, photo: photo)
  }

  @MainActor
  static func render(_ data: PublicProfileData, photo: UIImage? = nil) -> Data? {
    let card = PublicProfileCard(data: data, photoOverride: photo)
      .frame(width: contentWidth)
      .padding(24)
      .background(Color.white)
      .environment(\.colorScheme, .light)

    let renderer = ImageRenderer(content: card)
    renderer.scale = UIScreen.main.scale

    let pdfData = NSMutableData()
    var succeeded = false

    renderer.render { size, drawInContext in
      var mediaBox = CGRect(origin: .zero, size: size)
      guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
            let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        return
      }
      context.beginPDFPage(nil)
      drawInContext(context)
      context.endPDFPage()
      context.closePDF()
      succeeded = true
    }

    return succeeded ? (pdfData as Data) : nil
  }

  /// Downloads the header photo for embedding in the PDF. Returns nil on any failure (bad URL,
  /// network error, undecodable data) so the caller renders the placeholder instead.
  static func loadPhoto(_ urlString: String?) async -> UIImage? {
    guard let urlString, let url = URL(string: urlString) else { return nil }
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      return UIImage(data: data)
    } catch {
      return nil
    }
  }

  /// Safe filename for the export, e.g. "Jordan Sample" → "Jordan_Sample_Profile.pdf".
  static func filename(for playerName: String) -> String {
    let base = playerName
      .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
      .joined()
      .trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: " ", with: "_")
    let safe = base.isEmpty ? "Athlete" : base
    return "\(safe)_Profile.pdf"
  }
}
