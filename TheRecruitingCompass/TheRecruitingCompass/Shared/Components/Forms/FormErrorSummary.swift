//
//  FormErrorSummary.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-10
//  Phase 4: Reusable Components - Error summary banner for forms
//

import SwiftUI

struct FormErrorSummary: View {
  let errors: [String]
  let onDismiss: () -> Void

  var body: some View {
    if !errors.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.white)
            .accessibilityHidden(true)

          Text("Please fix the following errors:")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)

          Spacer()

          Button {
            onDismiss()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.white.opacity(0.7))
              .frame(minWidth: 44, minHeight: 44)
          }
          .accessibilityLabel(String(localized: "Dismiss error summary"))
        }

        VStack(alignment: .leading, spacing: 6) {
          ForEach(errors, id: \.self) { error in
            HStack(alignment: .top, spacing: 8) {
              Text("•")
                .foregroundStyle(.white)
                .accessibilityHidden(true)

              Text(error)
                .font(.caption)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }
      .padding()
      .background(Color.red)
      .clipShape(.rect(cornerRadius: 12))
      .accessibilityElement(children: .combine)
      .accessibilityLabel(String(localized: "Form errors"))
      .accessibilityValue("\(errors.count) error\(errors.count == 1 ? "" : "s"): \(errors.joined(separator: ", "))")
      .accessibilityAddTraits(.updatesFrequently)
      // `initial: true` because the summary is only in the tree while there are errors: the first failed
      // submit inserts it, and a plain onChange would stay silent until the errors change again.
      .onChange(of: errors, initial: true) { _, newValue in
        guard let message = Self.announcement(for: newValue) else { return }
        AccessibilityNotification.Announcement(message).post()
      }
    }
  }

  static func announcement(for errors: [String]) -> String? {
    guard !errors.isEmpty else { return nil }
    return "\(errors.count) error\(errors.count == 1 ? "" : "s"): \(errors.joined(separator: ". "))"
  }
}

#Preview {
  VStack(spacing: 16) {
    FormErrorSummary(
      errors: [
        "First name is required",
        "Please enter a valid email address",
        "Invalid Twitter handle"
      ],
      onDismiss: {}
    )

    FormErrorSummary(
      errors: ["First name is required"],
      onDismiss: {}
    )

    FormErrorSummary(
      errors: [],
      onDismiss: {}
    )
  }
  .padding()
}
