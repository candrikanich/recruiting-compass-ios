//
//  HelpBadge.swift
//  TheRecruitingCompass
//
//  Small inline badge for help content (New, Required, Optional).
//

import SwiftUI

struct HelpBadge: View {
  enum BadgeType {
    case new
    case required
    case optional

    var label: String {
      switch self {
      case .new: return "New"
      case .required: return "Required"
      case .optional: return "Optional"
      }
    }

    var color: Color {
      switch self {
      case .new: return .accentBlue
      case .required: return .errorRed
      case .optional: return Color.iconGray
      }
    }
  }

  let type: BadgeType

  var body: some View {
    Text(type.label)
      .font(.caption)
      .fontWeight(.semibold)
      .foregroundStyle(.white)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(type.color)
      .clipShape(Capsule())
      .accessibilityLabel(String(localized: "\(type.label)"))
  }
}

#Preview {
  HStack(spacing: 8) {
    HelpBadge(type: .new)
    HelpBadge(type: .required)
    HelpBadge(type: .optional)
  }
  .padding()
}
