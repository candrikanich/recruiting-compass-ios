import SwiftUI

struct EventMetricForm: View {
  private enum Layout {
    static let contentSpacing: CGFloat = 12
    static let unitFieldWidth: CGFloat = 80
    static let cornerRadius: CGFloat = 12
  }

  @Binding var data: NewMetricData
  let isSaving: Bool
  let onSave: () -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(spacing: Layout.contentSpacing) {
      // TODO(task-5/6/7): sport-filter
      Picker("Metric Type", selection: $data.metricType) {
        ForEach(MetricRegistry.types(forSport: nil).map(MetricType.init(rawValue:))) { type in
          Text(type.displayName).tag(type)
        }
      }
      .accessibilityLabel(String(localized: "Metric type"))
      .accessibilityHint("Select the type of metric to record")

      HStack(spacing: Layout.contentSpacing) {
        TextField("Value", text: $data.valueText)
          .keyboardType(.decimalPad)
          .textFieldStyle(.roundedBorder)
          .accessibilityLabel(String(localized: "Metric value"))
          .accessibilityHint("Enter a numeric value")

        TextField("Unit", text: $data.unit)
          .textFieldStyle(.roundedBorder)
          .frame(width: Layout.unitFieldWidth)
          .accessibilityLabel(String(localized: "Unit of measurement"))
          .accessibilityHint("Enter the unit, such as mph or seconds")
      }

      TextField("Notes (optional)", text: $data.notes, axis: .vertical)
        .lineLimit(2...4)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel(String(localized: "Metric notes"))

      HStack(spacing: Layout.contentSpacing) {
        Button("Cancel", action: onCancel)
          .buttonStyle(.bordered)
          .frame(minHeight: 44)
          .accessibilityLabel(String(localized: "Cancel adding metric"))

        Button(action: onSave) {
          if isSaving {
            ProgressView()
          } else {
            Text("Save Metric")
          }
        }
        .buttonStyle(.borderedProminent)
        .frame(minHeight: 44)
        .disabled(!data.isValid || isSaving)
        .accessibilityLabel(isSaving ? String(localized: "Saving metric") : String(localized: "Save metric"))
      }
    }
    .padding()
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
    .onChange(of: data.metricType) { _, newValue in
      if data.unit.isEmpty {
        data.unit = newValue.defaultUnit
      }
    }
  }
}
