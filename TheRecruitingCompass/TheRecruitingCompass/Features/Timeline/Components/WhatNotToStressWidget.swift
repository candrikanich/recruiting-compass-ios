import SwiftUI

/// Dashboard-style card showing reassurance messages for the current Timeline phase.
/// Ported for parity with the web "What NOT to Stress About" widget.
struct WhatNotToStressWidget: View {
  let phase: TimelinePhase

  var body: some View {
    let items = ReassuranceMessage.forPhase(phase)
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "Things that don't matter as much as you might think"))
        .font(.subheadline)
        .foregroundStyle(Color.secondaryText)

      if items.isEmpty {
        Text(String(localized: "No reassurance needed—you're doing great!"))
          .font(.subheadline)
          .foregroundStyle(Color.secondaryText)
      } else {
        ForEach(items) { item in
          HStack(alignment: .top, spacing: 8) {
            Text(item.icon)
            VStack(alignment: .leading, spacing: 4) {
              Text(item.title).font(.subheadline.weight(.medium))
              Text(item.message)
                .font(.body)
                .foregroundStyle(Color.secondaryText)
            }
          }
        }
      }
    }
  }
}
