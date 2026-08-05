import SwiftUI

struct ShareSheetView: View {
  let data: Data
  let filename: String
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    if let url = saveToTempFile() {
      ShareLink(item: url) {
        Label("Share \(filename)", systemImage: "square.and.arrow.up")
      }
      .onAppear {
        Task {
          try? await Task.sleep(for: .seconds(0.5))
          dismiss()
        }
      }
    } else {
      ContentUnavailableView(
        "Export Failed",
        systemImage: "exclamationmark.triangle",
        description: Text("Unable to prepare file for sharing")
      )
    }
  }

  private func saveToTempFile() -> URL? {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    do {
      try data.write(to: tempURL)
      return tempURL
    } catch {
      return nil
    }
  }
}
