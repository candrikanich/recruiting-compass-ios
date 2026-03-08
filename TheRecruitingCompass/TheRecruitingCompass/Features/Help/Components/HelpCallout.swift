//
//  HelpCallout.swift
//  TheRecruitingCompass
//
//  Tip / info / warning / important callout for help content.
//

import SwiftUI

struct HelpCallout: View {
  enum CalloutType {
    case tip
    case info
    case warning
    case important

    var icon: String {
      switch self {
      case .tip: return "lightbulb.fill"
      case .info: return "info.circle.fill"
      case .warning: return "exclamationmark.triangle.fill"
      case .important: return "flag.fill"
      }
    }

    var backgroundColor: Color {
      switch self {
      case .tip: return Color(red: 0.85, green: 0.95, blue: 0.88)
      case .info: return Color.accentBlue.opacity(0.12)
      case .warning: return Color.warningBackground
      case .important: return Color.errorBackground
      }
    }

    var iconColor: Color {
      switch self {
      case .tip: return .primaryGreen
      case .info: return .accentBlue
      case .warning: return .warningOrange
      case .important: return .errorRed
      }
    }
  }

  let type: CalloutType
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: type.icon)
        .font(.title3)
        .foregroundStyle(type.iconColor)
        .accessibilityHidden(true)

      Text(text)
        .font(.subheadline)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(type.backgroundColor)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabelForType)
  }

  private var accessibilityLabelForType: String {
    let typeLabel: String
    switch type {
    case .tip: typeLabel = "Tip"
    case .info: typeLabel = "Info"
    case .warning: typeLabel = "Warning"
    case .important: typeLabel = "Important"
    }
    return "\(typeLabel): \(text)"
  }
}

#Preview {
  VStack(spacing: 12) {
    HelpCallout(type: .tip, text: "You're in charge of your recruiting journey. The Recruiting Compass keeps everything organized so you can focus on making the right connections.")
    HelpCallout(type: .warning, text: "Removing a school permanently deletes all coach interactions and notes tied to that school.")
  }
  .padding()
}
