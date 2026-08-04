import SwiftUI
import PDFKit

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
        .clipShape(.rect(cornerRadius: 8))
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
