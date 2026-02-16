import SwiftUI

struct MetricFormView: View {
  @Binding var formState: MetricFormState
  let title: String
  let submitLabel: String
  let isSubmitting: Bool
  let onSubmit: () -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(title)
        .font(.title2)
        .fontWeight(.bold)

      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Metric Type")
            .font(.subheadline)
            .fontWeight(.medium)
          Picker("Metric Type", selection: $formState.metricType) {
            Text("Select Metric").tag(nil as MetricType?)
            ForEach(MetricType.allCases) { type in
              Text(type.displayName).tag(type as MetricType?)
            }
          }
          .pickerStyle(.menu)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(8)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .accessibilityLabel("Metric type selector")
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("Value")
            .font(.subheadline)
            .fontWeight(.medium)
          TextField("0.00", text: $formState.value)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Metric value")
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("Date")
            .font(.subheadline)
            .fontWeight(.medium)
          DatePicker("Date", selection: $formState.recordedDate, displayedComponents: .date)
            .labelsHidden()
            .accessibilityLabel("Recording date")
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("Unit")
            .font(.subheadline)
            .fontWeight(.medium)
          TextField("e.g., mph, sec, avg", text: $formState.unit)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Unit of measurement")
        }

        Toggle("Verified by third party", isOn: $formState.verified)
          .font(.subheadline)
          .accessibilityLabel("Verified by third party")

        VStack(alignment: .leading, spacing: 4) {
          Text("Notes")
            .font(.subheadline)
            .fontWeight(.medium)
          TextField("Additional context...", text: $formState.notes, axis: .vertical)
            .lineLimit(3...5)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Notes")
        }
      }

      HStack(spacing: 12) {
        Button(action: onSubmit) {
          Text(isSubmitting ? "Saving..." : submitLabel)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!formState.isValid || isSubmitting)
        .accessibilityLabel(submitLabel)

        Button(action: onCancel) {
          Text("Cancel")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Cancel")
      }
    }
    .padding()
  }
}
