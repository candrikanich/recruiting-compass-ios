//
//  SchoolPicker.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-10
//  Phase 4: Reusable Components - School selection picker for forms
//

import SwiftUI

struct SchoolPicker: View {
  @Binding var selectedSchoolId: String?
  let schools: [School]
  let isDisabled: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("School")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.secondary)

        Text("*")
          .font(.subheadline)
          .foregroundStyle(.red)
          .accessibilityHidden(true)

        Spacer()
      }

      Picker("Select School", selection: $selectedSchoolId) {
        Text("Select School")
          .tag(nil as String?)

        ForEach(schools) { school in
          Text(school.name)
            .tag(school.id as String?)
        }
      }
      .pickerStyle(.menu)
      .disabled(isDisabled)
      .accessibilityLabel(String(localized: "School, required"))
      .accessibilityHint("Select a school to add a coach to")
    }
  }
}

// Preview requires full School model initialization - see actual usage in AddCoachView
