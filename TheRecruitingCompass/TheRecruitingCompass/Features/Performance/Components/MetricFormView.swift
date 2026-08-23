import SwiftUI

struct MetricFormView: View {
  @Binding var formState: MetricFormState
  let title: String
  let submitLabel: String
  let isSubmitting: Bool
  /// The athlete's `primary_sport` — filters the Metric Type picker to that
  /// sport's metrics (falls back to the default baseball order when nil).
  let sport: String?
  let onSubmit: () -> Void
  let onCancel: () -> Void

  /// Picker options for the athlete's sport. When the sport defines metric
  /// groups (the 6 dense sports), each group renders as a headed `Section` and
  /// any key not in a group falls into a trailing "Other" section. Every other
  /// sport keeps the flat list — zero change.
  @ViewBuilder
  private var metricTypeOptions: some View {
    let allKeys = MetricRegistry.types(forSport: sport)
    let groups = MetricRegistry.groups(forSport: sport)
    if groups.isEmpty {
      ForEach(allKeys, id: \.self) { key in
        metricOption(for: key)
      }
    } else {
      let grouped = Set(groups.flatMap { $0.keys })
      ForEach(groups, id: \.category) { group in
        Section(header: Text(group.category)) {
          ForEach(group.keys, id: \.self) { key in
            metricOption(for: key)
          }
        }
      }
      let others = allKeys.filter { !grouped.contains($0) }
      if !others.isEmpty {
        Section(header: Text("Other")) {
          ForEach(others, id: \.self) { key in
            metricOption(for: key)
          }
        }
      }
    }
  }

  private func metricOption(for key: String) -> some View {
    let type = MetricType(rawValue: key)
    return Text(type.displayName).tag(type as MetricType?)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(title)
        .font(.title2)
        .bold()

      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Metric Type")
            .font(.subheadline)
            .fontWeight(.medium)
          Picker("Metric Type", selection: $formState.metricType) {
            Text("Select Metric").tag(nil as MetricType?)
            metricTypeOptions
          }
          .pickerStyle(.menu)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(8)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .accessibilityLabel(String(localized: "Metric type selector"))
        }

        if formState.metricType == .other {
          VStack(alignment: .leading, spacing: 4) {
            Text("Metric Name").font(.subheadline).fontWeight(.medium)
            TextField("e.g. Vertical Jump", text: $formState.otherName)
              .textFieldStyle(.roundedBorder)
              .accessibilityLabel(String(localized: "Custom metric name"))
          }
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("Value")
            .font(.subheadline)
            .fontWeight(.medium)
          TextField("0.00", text: $formState.value)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(String(localized: "Metric value"))
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("Date")
            .font(.subheadline)
            .fontWeight(.medium)
          DatePicker("Date", selection: $formState.recordedDate, displayedComponents: .date)
            .labelsHidden()
            .accessibilityLabel(String(localized: "Recording date"))
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("Unit")
            .font(.subheadline)
            .fontWeight(.medium)
          if let type = formState.metricType, !type.unitIsFixed {
            // "Other" — pick from the shared vocabulary.
            Picker("Unit", selection: $formState.unit) {
              ForEach(MetricType.unitVocabulary, id: \.self) { unit in
                Text(unit.isEmpty ? String(localized: "None") : unit).tag(unit)
              }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel(String(localized: "Unit of measurement"))
          } else {
            // Fixed unit — locked to the metric type (no user-typed units).
            Text(formState.unit.isEmpty ? String(localized: "None") : formState.unit)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(8)
              .background(Color(.systemGray6))
              .clipShape(RoundedRectangle(cornerRadius: 8))
              .accessibilityLabel(String(localized: "Unit of measurement"))
          }
        }

        Toggle("Verified by third party", isOn: $formState.verified)
          .font(.subheadline)
          .accessibilityLabel(String(localized: "Verified by third party"))

        VStack(alignment: .leading, spacing: 4) {
          Text("Notes")
            .font(.subheadline)
            .fontWeight(.medium)
          TextField("Additional context...", text: $formState.notes, axis: .vertical)
            .lineLimit(3...5)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(String(localized: "Notes"))
        }
      }

      HStack(spacing: 12) {
        Button(action: onSubmit) {
          Text(isSubmitting ? String(localized: "Saving...") : submitLabel)
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
        .accessibilityLabel(String(localized: "Cancel"))
      }
    }
    .padding()
    .onChange(of: formState.metricType) { _, newType in
      // Keep the unit canonical: locked types adopt their fixed unit; "Other"
      // falls back to the shared vocabulary (None) if the prior value isn't in it.
      guard let newType else { return }
      if newType.unitIsFixed {
        formState.unit = newType.defaultUnit
      } else if !MetricType.unitVocabulary.contains(formState.unit) {
        formState.unit = ""
      }
    }
  }
}
