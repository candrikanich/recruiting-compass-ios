//
//  HelpImageSlot.swift
//  TheRecruitingCompass
//
//  Placeholder for help screenshots/diagrams with caption (matches web HelpImageSlot).
//

import SwiftUI

struct HelpImageSlot: View {
  let caption: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.tertiarySystemFill))
        .frame(height: 120)
        .overlay(
          Image(systemName: "photo")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
        )
        .accessibilityHidden(true)

      Text(caption)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(caption)
  }
}

#Preview {
  HelpImageSlot(caption: "The main dashboard showing your school list and current phase.")
    .padding()
}
