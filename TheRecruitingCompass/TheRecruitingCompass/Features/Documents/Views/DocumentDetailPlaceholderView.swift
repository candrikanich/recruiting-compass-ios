import SwiftUI

struct DocumentDetailPlaceholderView: View {
  let documentId: String

  var body: some View {
    ContentUnavailableView {
      Label("Document Details", systemImage: "doc")
    } description: {
      Text("Document detail view coming in a future update.")
    }
    .navigationTitle("Document")
  }
}
