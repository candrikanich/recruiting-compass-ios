import Foundation

/// Builds the local file URL for a downloaded document. The title is user-controlled, so it can never choose
/// the directory: only a sanitized last component is kept, and the result must stay inside `directory`.
enum DownloadDestination {
  static func url(title: String?, fallbackBase: String, pathExtension: String, in directory: URL) -> URL? {
    let base = sanitizedComponent(title) ?? sanitizedComponent(fallbackBase) ?? UUID().uuidString
    let ext = pathExtension.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
    let name = ext.isEmpty ? base : base + "." + ext
    let destination = directory.appendingPathComponent(name)

    let root = directory.standardizedFileURL.path
    guard destination.standardizedFileURL.path.hasPrefix(root.hasSuffix("/") ? root : root + "/") else { return nil }
    return destination
  }

  private static func sanitizedComponent(_ raw: String?) -> String? {
    guard let raw else { return nil }
    let lastComponent = raw.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init) ?? ""
    let scalars = lastComponent.unicodeScalars.filter { $0.value >= 0x20 && $0.value != 0x7F }
    let cleaned = String(String.UnicodeScalarView(scalars))
      .replacingOccurrences(of: "..", with: "")
      .trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespacesAndNewlines))
    return cleaned.isEmpty ? nil : cleaned
  }
}
