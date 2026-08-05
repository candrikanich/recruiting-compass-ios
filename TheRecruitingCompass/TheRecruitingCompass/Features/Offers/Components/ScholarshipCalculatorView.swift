import SwiftUI

struct ScholarshipCalculatorView: View {
  let initialAmount: Double?
  let initialPercentage: Int?
  let onSaveToOffer: ((Double, Int) -> Void)?

  @State private var isExpanded = false
  @State private var annualCost: Double = 60_000
  @State private var scholarshipAmount: Double = 0
  @State private var scholarshipPercentage: Double = 0
  @State private var additionalAid: Double = 0
  @State private var years: Int = 4

  init(
    initialAmount: Double? = nil,
    initialPercentage: Int? = nil,
    onSaveToOffer: ((Double, Int) -> Void)? = nil
  ) {
    self.initialAmount = initialAmount
    self.initialPercentage = initialPercentage
    self.onSaveToOffer = onSaveToOffer
  }

  // MARK: - Computed

  private var annualScholarship: Double {
    if scholarshipAmount > 0 {
      return scholarshipAmount
    } else if scholarshipPercentage > 0 {
      return annualCost * scholarshipPercentage / 100
    }
    return 0
  }

  private var annualNetCost: Double {
    max(0, annualCost - annualScholarship - additionalAid)
  }

  private var totalScholarship: Double {
    annualScholarship * Double(years)
  }

  private var totalNetCost: Double {
    annualNetCost * Double(years)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      headerRow

      if isExpanded {
        inputSection
        Divider()
        resultsSection
        Divider()
        yearBreakdown

        if onSaveToOffer != nil {
          actionButtons
        }
      }
    }
    .padding()
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal)
    .accessibilityIdentifier("offer-scholarship-calculator")
    .onAppear {
      scholarshipAmount = initialAmount ?? 0
      scholarshipPercentage = Double(initialPercentage ?? 0)
    }
  }

  // MARK: - Subviews

  @ViewBuilder
  private var headerRow: some View {
    HStack {
      Text("Scholarship Calculator")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      Spacer()

      Button {
        withAnimation { isExpanded.toggle() }
      } label: {
        Text(isExpanded ? "Hide" : "Calculate")
          .font(.subheadline)
          .fontWeight(.semibold)
      }
      .buttonStyle(.bordered)
      .accessibilityLabel(isExpanded ? String(localized: "Hide scholarship calculator") : String(localized: "Scholarship Calculator"))
      .accessibilityHint(isExpanded ? "Collapses scholarship calculator" : "Expands scholarship calculator")
      .frame(minWidth: 44, minHeight: 44)
    }
  }

  @ViewBuilder
  private var inputSection: some View {
    VStack(spacing: 12) {
      calculatorField(
        label: String(localized: "Total Annual Cost ($)"),
        hint: "Tuition + room/board + fees",
        value: $annualCost
      )

      calculatorField(
        label: String(localized: "Scholarship Amount ($)"),
        hint: "Leave blank to use percentage",
        value: $scholarshipAmount
      )

      calculatorField(
        label: String(localized: "Scholarship Percentage (%)"),
        hint: "Leave blank if using amount",
        value: $scholarshipPercentage
      )

      calculatorField(
        label: String(localized: "Additional Aid/Grants ($)"),
        hint: "Non-scholarship aid",
        value: $additionalAid
      )

      VStack(alignment: .leading, spacing: 4) {
        Text("Years to Calculate")
          .font(.caption)
          .foregroundStyle(.secondary)

        Picker("Years", selection: $years) {
          ForEach(1...5, id: \.self) { year in
            Text("\(year) Year\(year == 1 ? "" : "s")").tag(year)
          }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(String(localized: "Number of years"))
      }
    }
  }

  @ViewBuilder
  private var resultsSection: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
      resultCard(label: "Annual Scholarship", value: annualScholarship, color: .blue)
      resultCard(label: "Annual Net Cost", value: annualNetCost, color: .orange)
      resultCard(label: "Total Scholarship (\(years)yr)", value: totalScholarship, color: .green)
      resultCard(label: "Total Net Cost (\(years)yr)", value: totalNetCost, color: .red)
    }
  }

  @ViewBuilder
  private var yearBreakdown: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Year-by-Year Breakdown")
        .font(.subheadline)
        .fontWeight(.semibold)

      ForEach(1...years, id: \.self) { year in
        HStack {
          Text("Year \(year)")
            .font(.caption)
            .fontWeight(.medium)
            .frame(width: 50, alignment: .leading)

          Spacer()

          Text(Self.formatCurrency(annualCost))
            .font(.caption)
            .foregroundStyle(.secondary)

          Text("-\(Self.formatCurrency(annualScholarship))")
            .font(.caption)
            .foregroundStyle(.green)

          Text("-\(Self.formatCurrency(additionalAid))")
            .font(.caption)
            .foregroundStyle(.blue)

          Text(Self.formatCurrency(annualNetCost))
            .font(.caption)
            .bold()
            .foregroundStyle(.red)
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          String(localized: "Year \(year): Cost \(Self.formatCurrency(annualCost)), Scholarship \(Self.formatCurrency(annualScholarship)), Your cost \(Self.formatCurrency(annualNetCost))")
        )
      }
    }
  }

  @ViewBuilder
  private var actionButtons: some View {
    HStack(spacing: 12) {
      Button {
        let pct = scholarshipPercentage > 0
          ? Int(scholarshipPercentage)
          : Int((annualScholarship / max(annualCost, 1)) * 100)
        onSaveToOffer?(annualScholarship, pct)
      } label: {
        Text("Save to Offer")
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity, minHeight: 44)
          .padding(.vertical, 8)
      }
      .buttonStyle(.borderedProminent)
      .tint(.green)
      .accessibilityHint("Applies calculator values to this offer")

      Button {
        scholarshipAmount = initialAmount ?? 0
        scholarshipPercentage = Double(initialPercentage ?? 0)
        additionalAid = 0
      } label: {
        Text("Reset")
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity, minHeight: 44)
          .padding(.vertical, 8)
      }
      .buttonStyle(.bordered)
      .accessibilityHint("Resets calculator to original offer values")
    }
  }

  // MARK: - Helpers

  private func calculatorField(
    label: String,
    hint: String,
    value: Binding<Double>
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)

      TextField(label, value: value, format: .number)
        .keyboardType(.numberPad)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel(label)
        .accessibilityHint(hint)

      Text(hint)
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
    }
  }

  private func resultCard(label: String, value: Double, color: Color) -> some View {
    VStack(spacing: 4) {
      Text(label)
        .font(.caption2)
        .foregroundStyle(color)

      Text(Self.formatCurrency(value))
        .font(.title3)
        .bold()
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(color.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(label): \(Self.formatCurrency(value))"))
  }

  private static func formatCurrency(_ value: Double) -> String {
    value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")
      .precision(.fractionLength(0)))
  }
}

#Preview {
  ScholarshipCalculatorView(
    initialAmount: 30000,
    initialPercentage: 50
  )
}
