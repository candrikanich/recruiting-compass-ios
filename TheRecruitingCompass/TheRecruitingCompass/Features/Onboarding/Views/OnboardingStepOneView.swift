import SwiftUI

/// Step 1 of the v2 onboarding: "Tell Us About You"
/// Collects primary sport (required, searchable), graduation year (required, segmented),
/// and zip code (optional). Gender is auto-derived from sport.
struct OnboardingStepOneView: View {
  @Bindable var viewModel: OnboardingV2ViewModel
  var onContinue: () -> Void

  @Environment(NuxProgressManager.self) private var nuxProgressManager

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        headerSection

        sportPickerSection

        graduationYearSection

        zipCodeSection

        Spacer(minLength: 24)

        continueButton
      }
      .padding(24)
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle("Tell Us About You")
    .navigationBarTitleDisplayMode(.large)
    .alert("Error", isPresented: .init(
      get: { viewModel.errorMessage != nil },
      set: { if !$0 { viewModel.clearError() } }
    )) {
      Button("OK") { viewModel.clearError() }
    } message: {
      Text(viewModel.errorMessage ?? "")
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("onboardingStepOne")
    .task { await viewModel.loadExistingData() }
  }

  // MARK: - Header

  @ViewBuilder private var headerSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Let's personalize your experience")
        .font(.body)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - Sport Picker

  @ViewBuilder private var sportPickerSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Primary Sport")
        .font(.subheadline.weight(.semibold))

      if viewModel.primarySport.isEmpty {
        sportSearchList
      } else {
        selectedSportBadge
      }
    }
  }

  @ViewBuilder private var sportSearchList: some View {
    VStack(spacing: 0) {
      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.tertiary)
        TextField("Search sports...", text: $viewModel.sportSearchText)
          .textFieldStyle(.plain)
          .autocorrectionDisabled()
      }
      .padding(12)
      .background(Color(uiColor: .secondarySystemGroupedBackground))
      .clipShape(RoundedRectangle(cornerRadius: 10))

      let sports = viewModel.filteredSports
      if !sports.isEmpty {
        LazyVStack(spacing: 0) {
          ForEach(sports, id: \.self) { sport in
            Button {
              viewModel.primarySport = sport
              viewModel.sportSearchText = ""
            } label: {
              HStack {
                Text(sport)
                  .foregroundStyle(.primary)
                Spacer()
                let sportGender = SportGenderMap.gender(for: sport)
                if sportGender != .neutral {
                  Text(sportGender == .male ? "M" : "W")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Capsule())
                }
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 10)
            }
            if sport != sports.last {
              Divider().padding(.leading, 12)
            }
          }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.top, 4)
      }
    }
  }

  @ViewBuilder private var selectedSportBadge: some View {
    HStack {
      Text(viewModel.primarySport)
        .font(.body.weight(.medium))
      Spacer()
      Button {
        viewModel.primarySport = ""
      } label: {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
      }
      .accessibilityLabel("Change sport")
    }
    .padding(12)
    .background(Color.accentColor.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  // MARK: - Graduation Year

  @ViewBuilder private var graduationYearSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Expected Graduation Year")
        .font(.subheadline.weight(.semibold))

      let years = OnboardingConstants.graduationYears
      // Show segmented for 4 or fewer years; otherwise use a picker
      if years.count <= 6 {
        segmentedGradYearPicker(years: years)
      } else {
        menuGradYearPicker(years: years)
      }
    }
  }

  private func segmentedGradYearPicker(years: [Int]) -> some View {
    // Use current year through current+3 for the segmented control (4 options)
    let displayYears = Array(years.prefix(4))
    return VStack(spacing: 8) {
      Picker("Graduation year", selection: Binding(
        get: { viewModel.graduationYear ?? 0 },
        set: { viewModel.graduationYear = $0 == 0 ? nil : $0 }
      )) {
        ForEach(displayYears, id: \.self) { year in
          Text(String(year)).tag(year)
        }
      }
      .pickerStyle(.segmented)

      // "Other" option for remaining years
      if years.count > 4 {
        let otherYears = Array(years.dropFirst(4))
        let selectedIsOther = viewModel.graduationYear.map { otherYears.contains($0) } ?? false
        if selectedIsOther {
          Picker("Other year", selection: Binding(
            get: { viewModel.graduationYear ?? otherYears.first ?? 0 },
            set: { viewModel.graduationYear = $0 }
          )) {
            ForEach(otherYears, id: \.self) { year in
              Text(String(year)).tag(year)
            }
          }
          .pickerStyle(.menu)
        } else {
          Button("Other year...") {
            viewModel.graduationYear = otherYears.first
          }
          .font(.footnote)
          .foregroundStyle(.secondary)
        }
      }
    }
  }

  private func menuGradYearPicker(years: [Int]) -> some View {
    Picker("Graduation year", selection: $viewModel.graduationYearDisplay) {
      Text("Select graduation year").tag("")
      ForEach(years, id: \.self) { year in
        Text(String(year)).tag(String(year))
      }
    }
    .pickerStyle(.menu)
  }

  // MARK: - Zip Code

  @ViewBuilder private var zipCodeSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 4) {
        Text("Zip Code")
          .font(.subheadline.weight(.semibold))
        Text("(optional)")
          .font(.subheadline)
          .foregroundStyle(.tertiary)
      }

      TextField("5-digit zip code", text: $viewModel.zipCode)
        .textFieldStyle(.roundedBorder)
        .keyboardType(.numberPad)
        .textContentType(.postalCode)
        .onChange(of: viewModel.zipCode) { _, newValue in
          // Limit to 5 digits
          let filtered = String(newValue.prefix(5).filter(\.isNumber))
          if filtered != newValue { viewModel.zipCode = filtered }
        }

      if let error = viewModel.zipCodeError {
        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
      } else {
        Text("Helps us find nearby schools")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    }
  }

  // MARK: - Continue Button

  @ViewBuilder private var continueButton: some View {
    Button {
      Task {
        if await viewModel.saveStep1() {
          nuxProgressManager.completeItem(.sport)
          onContinue()
        }
      }
    } label: {
      HStack {
        if viewModel.isLoading {
          ProgressView().tint(.white)
        } else {
          Text("Continue")
            .font(.body.weight(.semibold))
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 50)
    }
    .buttonStyle(.borderedProminent)
    .disabled(!viewModel.isStep1Valid || viewModel.isLoading || viewModel.zipCodeError != nil)
    .accessibilityIdentifier("onboardingContinueButton")
  }
}
