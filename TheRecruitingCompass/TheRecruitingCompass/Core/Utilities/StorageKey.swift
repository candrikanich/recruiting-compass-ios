import Foundation

/// Storage object keys are built from user-chosen file names, and Supabase Storage rejects some characters
/// (for example `|`) with "Invalid key" (ios#576). Only the key is sanitized; the name users see is not.
enum StorageKey {
  static let maxBaseLength = 100
  static let maxExtensionLength = 10
  static let fallbackBase = "file"

  private static let allowed = Set(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-".unicodeScalars)

  /// NFC-normalizes, splits at the last `.`, maps every Unicode scalar outside ASCII `[A-Za-z0-9._-]` to `_`,
  /// collapses runs of `_`, then caps the base at `maxBaseLength` and the extension at `maxExtensionLength`
  /// scalars. A base that is empty or only `_` becomes `fallbackBase`. Web mirrors this rule (web#1709). The
  /// caller's timestamp prefix, not this function, keeps repeat uploads of one name distinct.
  static func safeFileName(_ name: String) -> String {
    let scalars = name.precomposedStringWithCanonicalMapping.unicodeScalars
    let dot = scalars.lastIndex(of: ".")
    let base = clean(dot.map { scalars[..<$0] } ?? scalars[...], limit: maxBaseLength)
    let ext = clean(dot.map { scalars[scalars.index(after: $0)...] } ?? scalars[scalars.endIndex...],
                    limit: maxExtensionLength)
    let safeBase = base.allSatisfy { $0 == "_" } ? fallbackBase : base
    return ext.isEmpty ? safeBase : "\(safeBase).\(ext)"
  }

  private static func clean(_ scalars: String.UnicodeScalarView.SubSequence, limit: Int) -> String {
    var out = String.UnicodeScalarView()
    for scalar in scalars {
      let mapped: Unicode.Scalar = allowed.contains(scalar) ? scalar : "_"
      if mapped == "_", out.last == "_" { continue }
      out.append(mapped)
    }
    return String(String.UnicodeScalarView(out.prefix(limit)))
  }
}
