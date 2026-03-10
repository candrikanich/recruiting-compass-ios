import SwiftUI

struct DocumentPreviewCard: View {
  let document: Document

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Preview")
        .font(.headline)
      DocumentPreviewView(document: document)
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(.rect(cornerRadius: 12))
  }
}
