//
//  AutoFilledBadge.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-10
//  Phase 6: View Components - Auto-filled field indicator
//

import SwiftUI

/// Displays a small badge indicating that a field was auto-filled from College Scorecard API
/// Scaffolded for fast-follow feature (autocomplete), hidden in MVP
struct AutoFilledBadge: View {
  var body: some View {
    Text("(auto-filled)")
      .font(.caption)
      .foregroundStyle(.blue)
      .accessibilityLabel(String(localized: "auto-filled"))
      .accessibilityAddTraits(.isStaticText)
  }
}

#Preview {
  AutoFilledBadge()
}
