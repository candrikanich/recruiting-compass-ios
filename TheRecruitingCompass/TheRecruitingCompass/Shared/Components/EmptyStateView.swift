//
//  EmptyStateView.swift
//  TheRecruitingCompass
//
//  Generic empty state component with icon, title, message, and optional action
//

import SwiftUI

/// A reusable empty state component with icon, title, message, and optional action button
struct EmptyStateView: View {
  let icon: String
  let title: String
  let message: String
  let actionTitle: String?
  let action: (() -> Void)?

  @Environment(\.sizeCategory) private var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 56 : 48
  }

  init(
    icon: String,
    title: String,
    message: String,
    actionTitle: String? = nil,
    action: (() -> Void)? = nil
  ) {
    self.icon = icon
    self.title = title
    self.message = message
    self.actionTitle = actionTitle
    self.action = action
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: icon)
        .font(.system(size: iconSize))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      VStack(spacing: 4) {
        Text(title)
          .font(.headline)
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)

        Text(message)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }

      if let actionTitle, let action {
        Button {
          action()
        } label: {
          Label(actionTitle, systemImage: "plus.circle")
        }
        .buttonStyle(.borderedProminent)
        .frame(minHeight: 44)
        .accessibilityLabel(actionTitle)
      }
    }
    .padding()
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(title). \(message)"))
  }
}

#Preview("No Schools") {
  EmptyStateView(
    icon: "building.2.fill",
    title: "No Schools Found",
    message: "You need to add a school before adding a coach",
    actionTitle: "Add School"
  ) {}
}

#Preview("No Coaches") {
  EmptyStateView(
    icon: "person.2.slash",
    title: "No Coaches Yet",
    message: "Add coaches from your tracked schools to get started"
  )
}
