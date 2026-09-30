import SwiftUI

/// Column widths that put a two-column split exactly on a vertical fold (the iPhone Duo hinge), so
/// no column's text, controls or chart data straddles it. The gap is the hinge's reserved region,
/// margins included.
struct FoldSplit: Equatable {
  let leadingWidth: CGFloat
  let gap: CGFloat
  let trailingWidth: CGFloat

  /// Narrower than this and a column crushes its cards, so the regular layout is the better choice.
  static let minimumColumnWidth: CGFloat = 260

  init(leadingWidth: CGFloat, gap: CGFloat, trailingWidth: CGFloat) {
    self.leadingWidth = leadingWidth
    self.gap = gap
    self.trailingWidth = trailingWidth
  }

  /// Nil unless a region is a vertical band inside the container that leaves both sides usable.
  /// A horizontal fold (inner display rotated) can't be fixed by moving a column split, so it's ignored.
  init?(divisionRegions: [CGRect], containerSize: CGSize) {
    let hinge = divisionRegions.first { region in
      region.height >= region.width
        && region.minX >= Self.minimumColumnWidth
        && containerSize.width - region.maxX >= Self.minimumColumnWidth
    }
    guard let hinge else { return nil }

    self.init(
      leadingWidth: hinge.minX,
      gap: hinge.width,
      trailingWidth: containerSize.width - hinge.maxX
    )
  }
}

extension GeometryProxy {
  /// The vertical fold running through this view, in its own coordinates. Always nil when built with
  /// an SDK older than iOS 27.1 (SwiftUI 8.0.85), which lacks the reserved-region API.
  var verticalFoldSplit: FoldSplit? {
    #if canImport(SwiftUI, _version: 8.0.85)
    if #available(iOS 27.1, *) {
      let hinges = reservedRegions(kind: .division).map(\.frame)
      return FoldSplit(divisionRegions: hinges, containerSize: size)
    }
    #endif
    return nil
  }
}
