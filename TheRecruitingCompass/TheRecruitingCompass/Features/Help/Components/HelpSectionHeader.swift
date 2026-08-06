//
//  HelpSectionHeader.swift
//  TheRecruitingCompass
//
//  Section heading for help content, with optional badge.
//

import SwiftUI

struct HelpSectionHeader: View {
  let title: String
  var badge: HelpBadge.BadgeType?

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(title)
        .font(.headline)
        .foregroundStyle(.primary)

      if let badge {
        HelpBadge(type: badge)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.bottom, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(badge.map { String(localized: "\(title), \($0.label) badge") } ?? String(localized: "\(title)"))
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 16) {
    HelpSectionHeader(title: "Creating your profile")
    HelpSectionHeader(title: "Managing your school list", badge: .required)
  }
  .padding()
}
