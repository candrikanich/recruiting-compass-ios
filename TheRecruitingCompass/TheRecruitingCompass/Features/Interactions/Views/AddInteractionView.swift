import SwiftUI

struct AddInteractionView: View {
  @State private var viewModel: AddInteractionViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var hapticSuccessTrigger = 0
  @State private var hapticErrorTrigger = 0

  init(
    interactionsService: InteractionsManaging,
    familyUnitId: String,
    userId: String
  ) {
    _viewModel = State(initialValue: AddInteractionViewModel(
      interactionsService: interactionsService,
      familyUnitId: familyUnitId,
      userId: userId
    ))
  }

  var body: some View {
    Form {
      if viewModel.isLoading {
        LoadingStateView(message: "Loading form data...")
      } else {
        formSections
      }
    }
    .navigationTitle(viewModel.pageTitle)
    .navigationBarTitleDisplayMode(.inline)
    .scrollDismissesKeyboard(.interactively)
    .navigationBarBackButtonHidden(true)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") {
          dismiss()
        }
        .disabled(viewModel.isSubmitting)
        .accessibilityLabel(String(localized: "Cancel and return to school details"))
      }
    }
    .alert("Error", isPresented: $viewModel.isShowingErrorAlert) {
    } message: {
      if let error = viewModel.errorMessage {
        Text(error)
      }
    }
    .sheet(isPresented: $viewModel.showAddCoachSheet) {
      AddCoachSheet(
          firstName: $viewModel.newCoachForm.firstName,
          lastName: $viewModel.newCoachForm.lastName,
          role: $viewModel.newCoachForm.role,
          isValid: viewModel.newCoachForm.isValid,
          onSave: {
            Task {
              let success = await viewModel.createNewCoach()
              if success {
                viewModel.showAddCoachSheet = false
                hapticSuccessTrigger += 1
              }
            }
          }
        )
      }
    .sheet(isPresented: $viewModel.showOtherCoachSheet) {
      OtherCoachSheet(
        coachName: $viewModel.otherCoachName,
        onContinue: {
          viewModel.handleOtherCoach()
        }
      )
    }
    .task {
      await viewModel.loadFormData()
    }
    .sensoryFeedback(.success, trigger: hapticSuccessTrigger)
    .sensoryFeedback(.error, trigger: hapticErrorTrigger)
  }

  // MARK: - Form Sections

  @ViewBuilder
  private var formSections: some View {
    schoolSection
    coachSection
    interactionTypeSection
    directionSection
    dateTimeSection
    detailsSection
    sentimentSection

    if viewModel.formState.showsInterestCalibration {
      interestCalibrationSection
    }

    submitSection
  }

  // MARK: - School Section

  @ViewBuilder
  private var schoolSection: some View {
    Section {
      Picker("School", selection: $viewModel.formState.schoolId) {
        Text("Select a school").tag("")
        ForEach(viewModel.schools) { school in
          Text(school.name).tag(school.id)
        }
      }
      .accessibilityLabel(String(localized: "School picker"))
      .accessibilityHint("Required. Select the school for this interaction")
      .onChange(of: viewModel.formState.schoolId) { _, _ in
        viewModel.onSchoolChange()
      }
    } header: {
      HStack {
        Text("School")
        Text("*").foregroundStyle(.red)
      }
    }
  }

  // MARK: - Coach Section

  @ViewBuilder
  private var coachSection: some View {
    Section("Coach (Optional)") {
      Picker("Coach", selection: $viewModel.formState.coachId) {
        Text("No coach selected").tag(nil as String?)

        if !viewModel.schoolCoaches.isEmpty {
          ForEach(viewModel.schoolCoaches) { coach in
            Text("\(coach.firstName) \(coach.lastName) - \(coach.role.displayName)")
              .tag(coach.id as String?)
          }
        }

        Divider()
        Text("Other coach (not listed)").tag("other" as String?)
        Text("+ Add new coach").tag("add_new" as String?)
      }
      .accessibilityLabel(String(localized: "Coach picker"))
      .accessibilityHint("Optional. Select a coach or add a new one")
      .disabled(viewModel.formState.schoolId.isEmpty)
      .onChange(of: viewModel.formState.coachId) { _, newValue in
        if newValue == "other" {
          viewModel.formState.coachId = nil
          viewModel.showOtherCoachSheet = true
        } else if newValue == "add_new" {
          viewModel.formState.coachId = nil
          viewModel.showAddCoachSheet = true
        }
      }
    }
  }

  // MARK: - Type Section

  @ViewBuilder
  private var interactionTypeSection: some View {
    Section {
      Picker("Type", selection: $viewModel.formState.type) {
        Text("Select type").tag(nil as InteractionType?)

        ForEach(InteractionType.allCases, id: \.self) { type in
          Label(type.displayName, systemImage: type.iconName)
            .tag(type as InteractionType?)
        }
      }
      .accessibilityLabel(String(localized: "Interaction type picker"))
      .accessibilityHint("Required. Select the type of interaction")
    } header: {
      HStack {
        Text("Type")
        Text("*").foregroundStyle(.red)
      }
    }
  }

  // MARK: - Direction Section

  @ViewBuilder
  private var directionSection: some View {
    Section {
      Picker("Direction", selection: $viewModel.formState.direction) {
        ForEach(Direction.allCases, id: \.self) { direction in
          VStack(alignment: .leading) {
            Text(direction.displayName)
            Text(direction.subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .tag(direction)
        }
      }
      .pickerStyle(.segmented)
      .accessibilityLabel(String(localized: "Direction picker"))
      .accessibilityHint("Select outbound (we initiated) or inbound (they initiated)")
      .onChange(of: viewModel.formState.direction) { _, _ in
        viewModel.onDirectionOrSentimentChange()
      }
    } header: {
      HStack {
        Text("Direction")
        Text("*").foregroundStyle(.red)
      }
    }
  }

  // MARK: - Date/Time Section

  @ViewBuilder
  private var dateTimeSection: some View {
    Section("Date & Time") {
      DatePicker(
        "Occurred at",
        selection: $viewModel.formState.occurredAt,
        displayedComponents: [.date, .hourAndMinute]
      )
      .accessibilityLabel(String(localized: "Date and time picker"))
      .accessibilityHint("When this interaction occurred")
    }
  }

  // MARK: - Details Section

  @ViewBuilder
  private var detailsSection: some View {
    Section("Details (Optional)") {
      TextField("Subject", text: $viewModel.formState.subject, axis: .vertical)
        .lineLimit(2...4)
        .accessibilityLabel(String(localized: "Subject field"))
        .accessibilityHint("Optional. Email subject, call topic, etc. Max 500 characters")

      if viewModel.formState.subject.count > 450 {
        CharacterCountView(
          currentCount: viewModel.formState.subject.count,
          maxCount: 500
        )
      }

      TextEditor(text: $viewModel.formState.content)
        .frame(minHeight: 100)
        .accessibilityLabel(String(localized: "Content field"))
        .accessibilityHint("Optional. Details about the interaction. Max 10,000 characters")

      if viewModel.formState.content.count > 9500 {
        CharacterCountView(
          currentCount: viewModel.formState.content.count,
          maxCount: 10000
        )
      }
    }
  }

  // MARK: - Sentiment Section

  @ViewBuilder
  private var sentimentSection: some View {
    Section("Sentiment (Optional)") {
      Picker("How was this interaction?", selection: $viewModel.formState.sentiment) {
        Text("Not set").tag(nil as Sentiment?)

        ForEach(Sentiment.allCases, id: \.self) { sentiment in
          Text(sentiment.displayName).tag(sentiment as Sentiment?)
        }
      }
      .accessibilityLabel(String(localized: "Sentiment picker"))
      .accessibilityHint("Optional. Rate the tone of this interaction")
      .onChange(of: viewModel.formState.sentiment) { _, _ in
        viewModel.onDirectionOrSentimentChange()
      }
    }
  }

  // MARK: - Interest Calibration Section

  @ViewBuilder
  private var interestCalibrationSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 16) {
        Text("Coach Interest Level")
          .font(.headline)

        Text("Answer these questions to gauge the coach's level of interest based on their response.")
          .font(.caption)
          .foregroundStyle(.secondary)

        ForEach(Array(InterestCalibration.questions.enumerated()), id: \.offset) { index, question in
          Toggle(isOn: Binding(
            get: { viewModel.calibration.answers[index] },
            set: { newValue in
              viewModel.calibration.answers[index] = newValue
              viewModel.onCalibrationAnswerChange()
            }
          )) {
            Text(question)
              .fixedSize(horizontal: false, vertical: true)
          }
          .toggleStyle(.switch)
          .accessibilityLabel(question)
          .accessibilityValue(viewModel.calibration.answers[index] ? "Yes" : "No")
        }

        // Result card
        if viewModel.formState.interestLevel != .notSet {
          InterestResultCard(
            level: viewModel.formState.interestLevel,
            description: InterestCalibration().resultDescription
          )
        }
      }
    } header: {
      Text("Interest Calibration")
    }
  }

  // MARK: - Submit Section

  @ViewBuilder
  private var submitSection: some View {
    Section {
      Button(action: {
        Task {
          let success = await viewModel.submitInteraction()
          if success {
            hapticSuccessTrigger += 1
            dismiss()
          } else {
            hapticErrorTrigger += 1
          }
        }
      }) {
        HStack {
          Spacer()
          if viewModel.isSubmitting {
            ProgressView()
              .progressViewStyle(.circular)
          }
          Text(viewModel.submitButtonTitle)
          Spacer()
        }
      }
      .disabled(!viewModel.canSubmit)
      .buttonStyle(.borderedProminent)
      .accessibilityLabel(viewModel.submitButtonTitle)
      .accessibilityHint(viewModel.canSubmit ? "Submit this interaction" : "Cannot submit. Fill in required fields")

      Button("Cancel") {
        dismiss()
      }
      .buttonStyle(.bordered)
      .disabled(viewModel.isSubmitting)
    }
  }
}
