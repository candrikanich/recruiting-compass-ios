import SwiftUI

struct DocumentVersionHistoryCard: View {
  let versions: [DocumentVersion]
  let isUploadingNewVersion: Bool
  let uploadProgress: Double
  let onUploadTap: () -> Void
  let onRestore: (DocumentVersion) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Version History")
        .font(.headline)
      if versions.isEmpty {
        Text("No previous versions")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        ForEach(versions) { version in
          DocumentVersionRow(version: version, onRestore: onRestore)
        }
      }
      Button(action: onUploadTap) {
        Label("Upload New Version", systemImage: "plus")
          .font(.subheadline.weight(.medium))
          .frame(maxWidth: .infinity, minHeight: 44)
      }
      .accessibilityLabel(String(localized: "Upload New Version"))
      .accessibilityHint("Select a file to add a new version")
      .buttonStyle(.borderedProminent)
      .disabled(isUploadingNewVersion)
      .overlay {
        if isUploadingNewVersion {
          VStack(spacing: 8) {
            ProgressView(value: uploadProgress)
              .progressViewStyle(.linear)
              .tint(.white)
            Text("\(Int(uploadProgress * 100))%")
              .font(.caption)
              .foregroundStyle(.white)
          }
          .padding()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.black.opacity(0.6))
        }
      }
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(.rect(cornerRadius: 12))
  }
}
