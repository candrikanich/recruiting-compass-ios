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

          Spacer()

          Button {
            onDismiss()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.white.opacity(0.7))
          }
          .accessibilityLabel("Dismiss error summary")
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
            }
          }
        }
      }
      .padding()
      .background(Color.red)
      .cornerRadius(12)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Form errors")
      .accessibilityValue("\(errors.count) error\(errors.count == 1 ? "" : "s"): \(errors.joined(separator: ", "))")
      .accessibilityAddTraits(.updatesFrequently)
    }
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
