import SwiftUI

struct DocumentMetadataGrid: View {
  let document: Document
  let schoolName: String

  var body: some View {
    LazyVGrid(columns: [
      GridItem(.flexible()),
      GridItem(.flexible())
    ], spacing: 12) {
      DocumentMetadataItem(label: "Version", value: "v\(document.version)")
      DocumentMetadataItem(label: "School", value: schoolName)
      DocumentMetadataItem(label: "Uploaded", value: document.displayDate)
      DocumentMetadataItem(label: "File Type", value: document.fileType ?? "Unknown")
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(.rect(cornerRadius: 12))
  }
}
