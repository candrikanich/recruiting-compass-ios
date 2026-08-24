import SwiftUI

/// Dashboard-style card showing the athlete's top-ranked priorities for the current
/// Timeline phase. Ported for parity with the web "What Matters Right Now" widget.
/// v1 is display-only — the ranked list is provided by the caller, and rows do not
/// tap through to task detail yet.
struct WhatMattersNowWidget: View {
  let items: [WhatMattersItem]
  let phaseLabel: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "\(phaseLabel) year priorities to focus on"))
        .font(.subheadline)
        .foregroundStyle(Color.secondaryText)

      if items.isEmpty {
        Text(String(localized: "All tasks complete! Keep up the great work."))
          .font(.subheadline)
          .foregroundStyle(Color.secondaryText)
      } else {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
          HStack(alignment: .top, spacing: 8) {
            Text("\(index + 1)")
              .font(.caption.weight(.bold))
            VStack(alignment: .leading, spacing: 2) {
              Text(item.title)
                .font(.subheadline.weight(.medium))
              Text(item.whyItMatters)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .lineLimit(2)
            }
          }
        }
      }
    }
  }
}
