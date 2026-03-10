import Foundation

/// Represents a file to be attached to an interaction
struct AttachmentFile: Identifiable {
  let id = UUID()
  let fileName: String
  let fileSize: Int64
  let mimeType: String
  let data: Data

  /// File size in megabytes
  var fileSizeMB: Double {
    Double(fileSize) / (1024 * 1024)
  }

  /// Whether file exceeds the 10MB limit
  var isOverSizeLimit: Bool {
    fileSizeMB > 10.0
  }

  /// SF Symbol icon name based on file type
  var fileIcon: String {
    if mimeType.hasPrefix("image/") { return "photo" }
    if mimeType.contains("pdf") { return "doc.richtext" }
    if mimeType.contains("word") || mimeType.contains("document") { return "doc.text" }
    return "paperclip"
  }

  /// Formatted file size string
  var formattedSize: String {
    if fileSizeMB >= 1.0 {
      return fileSizeMB.formatted(.number.precision(.fractionLength(1))) + " MB"
    } else {
      let kb = Double(fileSize) / 1024
      return kb.formatted(.number.precision(.fractionLength(0))) + " KB"
    }
  }
}
