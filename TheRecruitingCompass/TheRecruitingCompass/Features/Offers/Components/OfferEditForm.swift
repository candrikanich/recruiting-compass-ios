import SwiftUI

struct OfferEditForm: View {
  @Binding var editData: OfferEditData
  let isUpdating: Bool
  let onSave: () async -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Edit Offer")
        .font(.headline)

      offerTypePicker
      statusPicker
      amountField
      percentageField
      offerDatePicker
      deadlineDatePicker
      conditionsField
      notesField

      actionButtons
    }
    .padding()
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal)
  }

  // MARK: - Form Fields

  private var offerTypePicker: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Offer Type")
        .font(.caption)
        .foregroundStyle(.secondary)

      Picker("Offer Type", selection: $editData.offerType) {
        ForEach(OfferType.allCases, id: \.self) { type in
          Text(type.displayName).tag(type)
        }
      }
      .pickerStyle(.menu)
      .accessibilityLabel("Offer type")
    }
  }

  private var statusPicker: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Status")
        .font(.caption)
        .foregroundStyle(.secondary)

      Picker("Status", selection: $editData.status) {
        ForEach(OfferStatus.allCases, id: \.self) { status in
          Text(status.displayName).tag(status)
        }
      }
      .pickerStyle(.menu)
      .accessibilityLabel("Offer status")
    }
  }

  private var amountField: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Scholarship Amount ($)")
        .font(.caption)
        .foregroundStyle(.secondary)

      TextField(
        "Amount",
        value: $editData.scholarshipAmount,
        format: .number
      )
      .keyboardType(.numberPad)
      .textFieldStyle(.roundedBorder)
      .accessibilityLabel("Scholarship amount in dollars")
    }
  }

  private var percentageField: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Scholarship Percentage (%)")
        .font(.caption)
        .foregroundStyle(.secondary)

      TextField(
        "Percentage",
        value: $editData.scholarshipPercentage,
        format: .number
      )
      .keyboardType(.numberPad)
      .textFieldStyle(.roundedBorder)
      .accessibilityLabel("Scholarship percentage, enter 0 to 100")
    }
  }

  private var offerDatePicker: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Offer Date")
        .font(.caption)
        .foregroundStyle(.secondary)

      DatePicker(
        "Offer Date",
        selection: $editData.offerDate,
        displayedComponents: .date
      )
      .labelsHidden()
      .accessibilityLabel("Offer date")
    }
  }

  private var deadlineDatePicker: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Deadline Date")
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack {
        if let deadline = editData.deadlineDate {
          DatePicker(
            "Deadline",
            selection: Binding(
              get: { deadline },
              set: { editData.deadlineDate = $0 }
            ),
            displayedComponents: .date
          )
          .labelsHidden()

          Button("Clear") {
            editData.deadlineDate = nil
          }
          .font(.caption)
          .foregroundStyle(.red)
        } else {
          Button("Set Deadline") {
            editData.deadlineDate = Date()
          }
          .font(.subheadline)
        }
      }
      .accessibilityLabel("Deadline date")
    }
  }

  private var conditionsField: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Conditions")
        .font(.caption)
        .foregroundStyle(.secondary)

      TextField("Conditions or requirements...", text: $editData.conditions, axis: .vertical)
        .lineLimit(3...6)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel("Offer conditions")
    }
  }

  private var notesField: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Notes")
        .font(.caption)
        .foregroundStyle(.secondary)

      TextField("Additional notes...", text: $editData.notes, axis: .vertical)
        .lineLimit(3...6)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel("Offer notes")
    }
  }

  // MARK: - Actions

  private var actionButtons: some View {
    HStack(spacing: 12) {
      Button {
        Task { await onSave() }
      } label: {
        if isUpdating {
          ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
          Text("Save Changes")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
      }
      .buttonStyle(.borderedProminent)
      .disabled(isUpdating)
      .accessibilityIdentifier("offer-save-button")
      .accessibilityLabel("Save Changes")
      .accessibilityHint("Saves edits to this offer")

      Button {
        onCancel()
      } label: {
        Text("Cancel")
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
      }
      .buttonStyle(.bordered)
      .disabled(isUpdating)
      .accessibilityIdentifier("offer-cancel-button")
      .accessibilityLabel("Cancel")
      .accessibilityHint("Discards changes and closes edit mode")
    }
  }
}
