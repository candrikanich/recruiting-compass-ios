//
//  HelpStepCard.swift
//  TheRecruitingCompass
//
//  Numbered step card for help center workflows.
//

import SwiftUI

struct HelpStepCard: View {
  let step: Int
  let title: String
  let bodyText: String
  var isLast: Bool = false

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Text("\(step)")
        .font(.brand(.title2))
        .bold()
        .foregroundStyle(Color.accentPrimary)
        .frame(width: 32, height: 32)
        .background(Color.accentPrimary.opacity(0.12))
        .clipShape(Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.brand(.body))
          .fontWeight(.semibold)
          .foregroundStyle(.primary)

        Text(bodyText)
          .font(.brand(.subheadline))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(12)
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.accentPrimary.opacity(0.3), lineWidth: isLast ? 0 : 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "Step \(step): \(title). \(bodyText)"))
  }
}

#Preview {
  VStack(spacing: 12) {
    HelpStepCard(step: 1, title: "Navigate to Settings", bodyText: "From the dashboard, go to Settings → Athlete Profile.")
    HelpStepCard(
      step: 2,
      title: "Fill in your details",
      bodyText: "Enter your name, graduation year, sport, position(s), GPA, and test scores.",
      isLast: true
    )
  }
  .padding()
}
