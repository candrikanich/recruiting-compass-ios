import SwiftUI

/// A layout that arranges views in a flowing, wrapping pattern.
/// Views are placed horizontally until they reach the container width, then wrap to the next line.
struct FlowLayout: Layout {
  let spacing: CGFloat

  init(spacing: CGFloat = 8) {
    self.spacing = spacing
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    var totalHeight: CGFloat = 0
    var totalWidth: CGFloat = 0

    var lineWidth: CGFloat = 0
    var lineHeight: CGFloat = 0

    for size in sizes {
      if lineWidth + size.width > (proposal.width ?? 0) {
        totalHeight += lineHeight + spacing
        lineWidth = size.width
        lineHeight = size.height
      } else {
        lineWidth += size.width + spacing
        lineHeight = max(lineHeight, size.height)
      }

      totalWidth = max(totalWidth, lineWidth)
    }

    totalHeight += lineHeight
    return CGSize(width: totalWidth, height: totalHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x = bounds.minX
    var y = bounds.minY
    var lineHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)

      if x + size.width > bounds.maxX {
        x = bounds.minX
        y += lineHeight + spacing
        lineHeight = 0
      }

      subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
      x += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }
  }
}
