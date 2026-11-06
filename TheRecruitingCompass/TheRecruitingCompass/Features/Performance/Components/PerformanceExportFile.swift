import Foundation

/// An export written to disk, so the system share sheet offers it as a named file rather than raw data.
struct PerformanceExportFile: Identifiable {
  let url: URL

  var id: URL { url }

  static func write(
    _ data: Data,
    named filename: String,
    in directory: URL = FileManager.default.temporaryDirectory
  ) throws -> PerformanceExportFile {
    let url = directory.appendingPathComponent(filename)
    try data.write(to: url, options: .atomic)
    return PerformanceExportFile(url: url)
  }
}
