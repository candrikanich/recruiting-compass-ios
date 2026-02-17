import SwiftUI

struct AddOfferForm: View {
  @Binding var formState: NewOfferFormState
  let schools: [School]
  let isSubmitting: Bool
  let onSave: () -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Log New Offer")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      SchoolPicker(
        selectedSchoolId: $formState.schoolId,
        schools: schools,
        isDisabled: isSubmitting
      )

      Picker("Offer Type", selection: $formState.offerType) {
        ForEach(OfferType.allCases, id: \.self) { type in
          Text(type.displayName).tag(type)
        }
      }
      .accessibilityLabel("Offer type")

      Picker("Status", selection: $formState.status) {
        ForEach(OfferStatus.allCases, id: \.self) { status in
          Text(status.displayName).tag(status)
        }
      }
      .accessibilityLabel("Offer status")

      VStack(alignment: .leading, spacing: 4) {
        Text("Scholarship %")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        Stepper("\(formState.scholarshipPercentage)%", value: $formState.scholarshipPercentage, in: 0...100, step: 5)
          .accessibilityLabel("Scholarship percentage, \(formState.scholarshipPercentage) percent")
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("Scholarship Amount")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        TextField("e.g. 50000", text: $formState.scholarshipAmount)
          .keyboardType(.decimalPad)
          .textFieldStyle(.roundedBorder)
          .accessibilityLabel("Scholarship amount in dollars")
      }

      DatePicker("Offer Date", selection: $formState.offerDate, displayedComponents: .date)
        .accessibilityLabel("Offer date")

      Toggle("Has Deadline", isOn: $formState.hasDeadline)
        .accessibilityLabel("Offer has a deadline")

      if formState.hasDeadline {
        DatePicker("Deadline", selection: $formState.deadlineDate, displayedComponents: .date)
          .accessibilityLabel("Deadline date")
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("Notes")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        TextEditor(text: $formState.notes)
          .frame(minHeight: 60)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color(.systemGray4), lineWidth: 1)
          )
          .accessibilityLabel("Offer notes")
      }

      if !formState.validationErrors.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(formState.validationErrors, id: \.self) { error in
            Text(error)
              .font(.caption)
              .foregroundColor(.errorRed)
              .accessibilityLabel("Error: \(error)")
          }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Form errors: \(formState.validationErrors.joined(separator: ", "))")
      }

      HStack {
        Button("Cancel") {
          onCancel()
        }
        .frame(minHeight: 44)
        .accessibilityLabel("Cancel adding offer")

        Spacer()

        Button {
          onSave()
        } label: {
          if isSubmitting {
            ProgressView()
              .frame(minWidth: 44, minHeight: 44)
          } else {
            Text("Save Offer")
              .fontWeight(.semibold)
              .frame(minHeight: 44)
          }
        }
        .disabled(!formState.isValid || isSubmitting)
        .accessibilityLabel("Save offer")
        .accessibilityHint(isSubmitting ? "Saving in progress" : "Double tap to save offer")
      }
    }
    .padding(16)
    .background(Color(.secondarySystemBackground))
    .cornerRadius(12)
  }
}
