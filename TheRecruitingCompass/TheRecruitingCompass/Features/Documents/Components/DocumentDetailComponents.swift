import SwiftUI

// MARK: - Document Header Card

struct DocumentHeaderCard: View {
  let document: Document
  let onEdit: () -> Void
  let onShare: () -> Void
  let onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          Text("\(document.typeEmoji) \(document.typeLabel)")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentBlue.opacity(0.2))
            .foregroundStyle(.primary)
            .clipShape(.rect(cornerRadius: 6))
          Text(document.title)
            .font(.title2)
            .bold()
            .lineLimit(2)
            .truncationMode(.tail)
          if let desc = document.description, !desc.isEmpty {
            Text(desc)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()
      }
      HStack(spacing: 12) {
        Button(action: onEdit) {
          Label("Edit", systemImage: "pencil")
            .font(.subheadline.weight(.medium))
            .frame(minWidth: 88, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentBlue)
        .accessibilityLabel("Edit document metadata")

        Button(action: onShare) {
          Label("Share", systemImage: "square.and.arrow.up")
            .font(.subheadline.weight(.medium))
            .frame(minWidth: 88, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.primaryGreen)
        .accessibilityLabel("Share document with schools")

        Button(role: .destructive, action: onDelete) {
          Label("Delete", systemImage: "trash")
            .font(.subheadline.weight(.medium))
            .frame(minWidth: 88, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.errorRed)
        .accessibilityLabel("Delete document")
        .accessibilityHint("This action cannot be undone")
      }
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(.rect(cornerRadius: 12))
  }
}

// MARK: - Document Metadata Grid

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

struct DocumentMetadataItem: View {
  let label: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.subheadline)
        .fontWeight(.medium)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Document Error Banner

struct DocumentErrorBanner: View {
  let error: String
  let onRetry: () -> Void

  var body: some View {
    HStack {
      Text(error)
        .font(.caption)
        .foregroundStyle(.white)
      Spacer()
      Button("Retry", action: onRetry)
        .font(.caption)
        .foregroundStyle(.white)
    }
    .padding()
    .background(Color.errorRed)
    .clipShape(.rect(cornerRadius: 8))
  }
}

// MARK: - Document Preview Card

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

// MARK: - Document Version History Card

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
      .accessibilityLabel("Upload New Version")
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

// MARK: - Document Version Row

struct DocumentVersionRow: View {
  let version: DocumentVersion
  let onRestore: (DocumentVersion) -> Void

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text("v\(version.version)")
            .font(.subheadline)
            .fontWeight(.semibold)
          if version.isCurrent {
            Text("Current")
              .font(.caption)
              .fontWeight(.semibold)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.accentBlue.opacity(0.2))
              .clipShape(.rect(cornerRadius: 4))
          }
        }
        Text(version.displayDate)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      HStack(spacing: 8) {
        if let url = URL(string: version.fileUrl) {
          Link(destination: url) {
            Text("View")
              .font(.caption)
          }
          .buttonStyle(.bordered)
        }
        if !version.isCurrent {
          Button("Restore") {
            onRestore(version)
          }
          .font(.caption)
          .buttonStyle(.bordered)
          .frame(minHeight: 44)
          .contentShape(Rectangle())
          .accessibilityLabel("Restore version \(version.version)")
          .accessibilityHint("Restores this version as the current document")
        }
      }
    }
    .padding(.vertical, 8)
  }
}
