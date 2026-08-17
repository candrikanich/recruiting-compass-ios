//
//  EmptyStateView.swift
//  TheRecruitingCompass
//
//  Generic empty state component with icon, title, message, and optional action
//

import SwiftUI

/// A reusable empty state component with icon, title, message, and optional action button.
///
/// The action button renders full-width, semibold, and bordered-prominent with a 44pt
/// minimum hit target, so every "your first …" empty state across the app is visually identical.
struct EmptyStateView: View {
  let icon: String
  let title: String
  let message: String
  let actionTitle: String?
  let actionHint: String?
  let action: (() -> Void)?

  @Environment(\.sizeCategory) private var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 72 : 60
  }

  init(
    icon: String,
    title: String,
    message: String,
    actionTitle: String? = nil,
    actionHint: String? = nil,
    action: (() -> Void)? = nil
  ) {
    self.icon = icon
    self.title = title
    self.message = message
    self.actionTitle = actionTitle
    self.actionHint = actionHint
    self.action = action
  }

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: icon)
        .font(.system(size: iconSize))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      VStack(spacing: 8) {
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
      .accessibilityElement(children: .combine)

      if let actionTitle, let action {
        Button(action: action) {
          Text(actionTitle)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .accessibilityLabel(actionTitle)
        .accessibilityHint(actionHint ?? "")
      }
    }
    .padding(40)
    .frame(maxWidth: .infinity)
  }
}

#Preview("With Action") {
  EmptyStateView(
    icon: "calendar",
    title: "No Events Yet",
    message: "Create your first event to track camps, showcases, visits, and games.",
    actionTitle: "Add Your First Event",
    actionHint: "Opens the form to create an event"
  ) {}
}

#Preview("No Action") {
  EmptyStateView(
    icon: "person.2.slash",
    title: "No Coaches Yet",
    message: "Add coaches from your tracked schools to get started"
  )
}
