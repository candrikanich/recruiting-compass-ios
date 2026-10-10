import SwiftUI

/// Dashboard-style card showing reassurance messages for the current Timeline phase.
/// Ported for parity with the web "What NOT to Stress About" widget.
struct WhatNotToStressWidget: View {
  let phase: TimelinePhase

  var body: some View {
    let items = ReassuranceMessage.forPhase(phase)
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "Things that don't matter as much as you might think"))
        .font(.brand(.subheadline))
        .foregroundStyle(Color.secondaryText)

      if items.isEmpty {
        Text(String(localized: "No reassurance needed—you're doing great!"))
          .font(.brand(.subheadline))
          .foregroundStyle(Color.secondaryText)
      } else {
        ForEach(items) { item in
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.systemImage)
              .foregroundStyle(Color.accentPrimary)
              .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
              Text(item.title).font(.brand(.subheadline, weight: .medium))
              Text(item.message)
                .font(.brand(.body))
                .foregroundStyle(Color.secondaryText)
            }
          }
        }
      }
    }
  }
}
