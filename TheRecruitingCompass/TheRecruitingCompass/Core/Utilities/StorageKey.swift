import Foundation

/// Storage object keys are built from user-chosen file names, and Supabase Storage rejects some characters
/// (for example `|`) with "Invalid key" (ios#576). Only the key is sanitized; the name users see is not.
enum StorageKey {
  static let maxBaseLength = 100
  static let maxExtensionLength = 10
  static let fallbackBase = "file"

  private static let allowed = Set(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-".unicodeScalars)

  /// Splits at the last `.` and works per Unicode scalar (not grapheme, not UTF-16 unit). Keeps ASCII
  /// `[A-Za-z0-9._-]` and maps every other scalar to `_`. The base is capped at `maxBaseLength` scalars and the
  /// extension at `maxExtensionLength`. A base that is empty or only `_` becomes `fallbackBase`. Web mirrors
  /// this rule (web#1709). The caller's timestamp prefix, not this function, keeps repeat uploads distinct.
  static func safeFileName(_ name: String) -> String {
    let scalars = name.unicodeScalars
    let dot = scalars.lastIndex(of: ".")
    let base = clean(dot.map { scalars[..<$0] } ?? scalars[...], limit: maxBaseLength)
    let ext = clean(dot.map { scalars[scalars.index(after: $0)...] } ?? scalars[scalars.endIndex...],
                    limit: maxExtensionLength)
    let safeBase = base.allSatisfy { $0 == "_" } ? fallbackBase : base
    return ext.isEmpty ? safeBase : "\(safeBase).\(ext)"
  }

  private static func clean(_ scalars: String.UnicodeScalarView.SubSequence, limit: Int) -> String {
    var out = String.UnicodeScalarView()
    out.append(contentsOf: scalars.prefix(limit).map { allowed.contains($0) ? $0 : "_" })
    return String(out)
  }
}
