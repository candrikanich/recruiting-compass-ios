//
//  FormFieldWrapper.swift
//  TheRecruitingCompass
//
//  Reusable wrapper for form fields with label, required indicator, and error display
//

import SwiftUI

/// Wraps form fields with consistent label, required indicator, and error display
struct FormFieldWrapper<Content: View>: View {
  let label: String
  let isRequired: Bool
  let error: String?
  @ViewBuilder let content: () -> Content

  init(
    label: String,
    isRequired: Bool = false,
    error: String? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.label = label
    self.isRequired = isRequired
    self.error = error
    self.content = content
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Label with required indicator
      HStack {
        Text(label)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.secondary)

        if isRequired {
          Text("*")
            .font(.subheadline)
            .foregroundStyle(.red)
            .accessibilityHidden(true)
        }

        Spacer()
      }

      // Field content
      content()

      // Error display
      FieldError(error: error)
    }
    // ✅ Accessibility: Semantic grouping for screen readers
    .accessibilityElement(children: .combine)
    .accessibilityLabel(buildAccessibilityLabel())
  }

  // MARK: - Helper Methods

  /// Builds an accessible label combining field name, required status, and error
  private func buildAccessibilityLabel() -> String {
    var accessibleLabel = label

    if isRequired {
      accessibleLabel += ", required"
    }

    if let error {
      accessibleLabel += ", error: \(error)"
    }

    return accessibleLabel
  }
}

#Preview("Required Field") {
  Form {
    FormFieldWrapper(label: "First Name", isRequired: true) {
      TextField("e.g., John", text: .constant(""))
        .textFieldStyle(.roundedBorder)
    }
  }
}

#Preview("Optional Field with Error") {
  Form {
    FormFieldWrapper(
      label: "Email",
      isRequired: false,
      error: "Invalid email format"
    ) {
      TextField("email@example.com", text: .constant("invalid"))
        .textFieldStyle(.roundedBorder)
    }
  }
}
