//
//  FieldError.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-10
//  Phase 4: Reusable Components - Inline error display for form fields
//

import SwiftUI

struct FieldError: View {
  let error: String?

  var body: some View {
    if let error {
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.circle.fill")
          .font(.caption)
          .foregroundStyle(.red)
          .accessibilityHidden(true)

        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Error: \(error)")
    }
  }
}

#Preview {
  VStack(spacing: 16) {
    FieldError(error: "This field is required")
    FieldError(error: "Please enter a valid email address")
    FieldError(error: nil)
  }
  .padding()
}
