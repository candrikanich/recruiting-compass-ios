import MessageUI
import SwiftUI

/// Quick Communication sheet: a channel-first wizard. Step 1 picks the channel (Email / Text /
/// Instagram), Step 2 composes (template + variables + editor), Step 3 previews and sends. Splitting
/// the flow across pushed screens keeps each screen short instead of one endless scroll.
struct QuickCommunicationView: View {
  let context: QuickCommunicationContext

  @State private var viewModel: QuickCommunicationViewModel
  @State private var path = NavigationPath()
  @State private var activeComposer: ActiveComposer?
  @State private var showSuccessToast = false
  @State private var showInfoToast = false
  @State private var infoMessage: String?
  @State private var showMetricsSheet = false
  @Environment(\.openURL) private var openURL
  @Environment(\.dismiss) private var dismiss
  @Environment(FamilyManager.self) private var familyManager
  @Environment(AuthManager.self) private var authManager

  init(context: QuickCommunicationContext) {
    self.context = context
    _viewModel = State(initialValue: QuickCommunicationViewModel(
      coach: context.coach,
      schoolName: context.schoolName
    ))
  }

  private enum ActiveComposer: Identifiable {
    case mail, message
    var id: Self { self }
  }

  var body: some View {
    NavigationStack(path: $path) {
      QuickCommChannelScreen(
        recipientLine: viewModel.recipientLine,
        showEmail: viewModel.mailtoURL() != nil,
        showText: viewModel.smsURL() != nil,
        instagramHandle: context.coach.contactInstagram,
        onOpenInstagram: { openURL($0) }
      )
      .navigationTitle("Quick Communication")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
          NavigationLink(value: QuickCommDestination.manageTemplates) {
            Text("Manage Templates")
          }
        }
      }
      .navigationDestination(for: QuickCommDestination.self) { destination in
        switch destination {
        case .manageTemplates:
          CommunicationTemplatesView()
        }
      }
      .navigationDestination(for: QuickCommStep.self) { step in
        switch step {
        case .template(let channel):
          templateScreen(channel: channel)
        case .details(let channel):
          detailsScreen(channel: channel)
        case .completeInfo(let channel):
          completeInfoScreen(channel: channel)
        case .preview(let channel):
          previewScreen(channel: channel)
        }
      }
      .task {
        viewModel.configureContext(
          loggedBy: authManager.user?.id,
          familyUnitId: familyManager.currentMember?.familyUnitId,
          athleteUserId: familyManager.selectedAthlete?.userId,
          accessToken: authManager.session?.accessToken
        )
        await viewModel.loadTemplates()
        await viewModel.loadVideoLinks()
        await viewModel.loadResolverInputs()
      }
      .accessibilityIdentifier("quickCommunicationView")
    }
  }

  // MARK: - Step 2: Pick template

  @ViewBuilder
  private func templateScreen(channel: QuickCommChannel) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        QuickCommTemplateSection(
          isLoading: viewModel.isLoading,
          templates: channel == .email ? viewModel.emailTemplates : viewModel.textTemplates,
          selectedTemplate: viewModel.selectedTemplate,
          onSelect: { viewModel.selectTemplate($0) }
        )
      }
      .padding()
    }
    .navigationTitle(channel == .email ? "Email Template" : "Text Template")
    .navigationBarTitleDisplayMode(.inline)
    .safeAreaInset(edge: .bottom) {
      NavigationLink(value: QuickCommStep.details(channel)) {
        Text("Next")
          .font(.body.weight(.medium))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
      }
      .buttonStyle(.borderedProminent)
      .padding()
      .background(.bar)
      .accessibilityIdentifier("quickCommTemplateNext")
    }
    .onAppear {
      // Dropping into a channel whose type doesn't match the carried-over template clears it,
      // so the picker's selection state matches the templates actually shown.
      if let selected = viewModel.selectedTemplate,
         selected.type != channel.templateType {
        viewModel.selectTemplate(nil)
      }
    }
  }

  // MARK: - Step 3: Fill in details

  @ViewBuilder
  private func detailsScreen(channel: QuickCommChannel) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        if channel == .email {
          QuickCommSubjectField(subject: subjectBinding)
        }
        QuickCommBodyEditor(
          text: bodyBinding,
          isTextMessage: channel == .text,
          characterCount: viewModel.effectiveBody.count,
          limit: QuickCommunicationViewModel.textLimit,
          overLimit: viewModel.textBodyOverLimit
        )
      }
      .padding()
    }
    .navigationTitle("Fill in the Details")
    .navigationBarTitleDisplayMode(.inline)
    .safeAreaInset(edge: .bottom) {
      Button {
        // Collect any unresolved template data in the unified step; skip straight to
        // preview when the template resolves fully.
        path.append(viewModel.hasMissingInfo
          ? QuickCommStep.completeInfo(channel) : QuickCommStep.preview(channel))
      } label: {
        Text("Preview & Send")
          .font(.body.weight(.medium))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
      }
      .buttonStyle(.borderedProminent)
      .padding()
      .background(.bar)
      .accessibilityIdentifier("quickCommPreviewLink")
    }
  }

  // MARK: - Step 3b: Complete your info (unified missing-data collection)

  /// One consistent form for every unresolved thing the template needs — the single
  /// replacement for the old inline vars panel, metrics CTA, separate specificity step,
  /// and two pre-send alerts. Continue is always enabled (required tokens still gate the
  /// actual Send at preview); persists prefs-backed answers, then routes to preview.
  @ViewBuilder
  private func completeInfoScreen(channel: QuickCommChannel) -> some View {
    let isParent = familyManager.currentMember?.isParent == true
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("A few details make this message land with \(viewModel.schoolDisplayName).")
          .font(.caption)
          .foregroundStyle(.secondary)

        ForEach(viewModel.missingInfoFields) { field in
          missingInfoRow(field, isParent: isParent)
        }

        if isParent && viewModel.missingInfoFields.contains(where: { !$0.editableByParent }) {
          Text("Ask the athlete to answer these.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }
      .padding()
    }
    .navigationTitle("Complete Your Info")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showMetricsSheet, onDismiss: {
      Task { await viewModel.loadResolverInputs() }  // pick up any metric just added
    }) {
      NavigationStack { PerformanceDashboardView() }
    }
    .safeAreaInset(edge: .bottom) {
      Button {
        Task {
          await viewModel.commitMissingInfo()  // persist prefs-backed + questionnaire answers
          path.append(QuickCommStep.preview(channel))
        }
      } label: {
        Text("Continue")
          .font(.body.weight(.medium))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
      }
      .buttonStyle(.borderedProminent)
      .padding()
      .background(.bar)
      .accessibilityIdentifier("quickCommCompleteInfoContinue")
    }
  }

  /// Renders one missing-info field with the editor its descriptor calls for.
  @ViewBuilder
  private func missingInfoRow(
    _ field: QuickCommunicationViewModel.MissingInfoField, isParent: Bool) -> some View {
    switch field.editor {
    case .text(let multiline):
      QuickCommSpecificityField(
        title: field.title,
        prompt: field.prompt,
        text: viewModel.missingInfoBinding(for: field),
        disabled: isParent && !field.editableByParent,
        singleLine: !multiline)
    case .boolean:
      QuickCommQuestionnaireField(
        title: field.title,
        prompt: field.prompt,
        completed: $viewModel.questionnaireMarkedCompleted)
    case .metricLink:
      QuickCommAddMetricCTA { showMetricsSheet = true }
    }
  }

  // MARK: - Step 3: Preview & Send

  @ViewBuilder
  private func previewScreen(channel: QuickCommChannel) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        QuickCommBodyPreview(
          preview: UnresolvedTokenHighlighter.attributed(
            viewModel.cleanBody, tokenColor: .warningOrange),
          plainBody: viewModel.cleanBody
        )
        if viewModel.isSendBlocked {
          Text("Fill these before sending: \(viewModel.unresolvedKeys.joined(separator: ", "))")
            .font(.caption)
            .foregroundStyle(Color.warningOrange)
            .accessibilityIdentifier("quickCommUnresolvedNotice")
        }
        if let warning = viewModel.sendWarning {
          Text(warning)
            .font(.caption)
            .foregroundStyle(Color.warningOrange)
            .accessibilityIdentifier("quickCommSendWarning")
        }
      }
      .padding()
    }
    .navigationTitle("Preview")
    .navigationBarTitleDisplayMode(.inline)
    .safeAreaInset(edge: .bottom) {
      QuickCommActionsSection(
        showEmail: channel == .email,
        showText: channel == .text,
        coachEmail: context.coach.email ?? "",
        sendDisabled: viewModel.isSendBlocked,
        onSendEmail: handleSendEmail,
        onSendText: handleSendText
      )
      .padding()
      .background(.bar)
    }
    // Presentation lives on the preview screen — the view that triggers it. Bound to the
    // NavigationStack root instead, these fail to present over the pushed preview.
    .sheet(item: $activeComposer) { composer in
      composerSheet(for: composer)
    }
    .toast(isShowing: $showSuccessToast, message: $viewModel.successMessage, type: .success, duration: 3.0)
    .toast(isShowing: $showInfoToast, message: $infoMessage, type: .info, duration: 3.0)
  }

  // MARK: - Edit bindings

  /// Writes user edits into the VM overrides; reads the effective (edited-or-resolved) text.
  private var subjectBinding: Binding<String> {
    Binding(get: { viewModel.effectiveSubject },
            set: { viewModel.editedSubject = $0 })
  }
  private var bodyBinding: Binding<String> {
    Binding(get: { viewModel.effectiveBody },
            set: { viewModel.editedBody = $0 })
  }

  // MARK: - Send handling

  /// Present the in-app mail composer when the device can send mail; otherwise fall back to the
  /// `mailto:` hand-off and log NOTHING (an external hand-off can't confirm the send).
  private func handleSendEmail() {
    Task {
      guard await viewModel.evaluateGuardrails(.email) else { return }  // blocked or armed → stop
      if MFMailComposeViewController.canSendMail() {
        activeComposer = .mail
      } else if let url = viewModel.mailtoURL() {
        openURL(url)
        infoMessage = String(localized: "Log it from Interactions once sent.")
        showInfoToast = true
      }
    }
  }

  /// Present the in-app message composer when the device can send texts; otherwise fall back to the
  /// `sms:` hand-off and log NOTHING.
  private func handleSendText() {
    Task {
      guard await viewModel.evaluateGuardrails(.text) else { return }
      if MFMessageComposeViewController.canSendText() {
        activeComposer = .message
      } else if let url = viewModel.smsURL() {
        openURL(url)
        infoMessage = String(localized: "Log it from Interactions once sent.")
        showInfoToast = true
      }
    }
  }

  @ViewBuilder
  private func composerSheet(for composer: ActiveComposer) -> some View {
    switch composer {
    case .mail:
      MailComposeView(
        recipients: [context.coach.email].compactMap { $0 },
        subject: viewModel.cleanSubject.isEmpty ? viewModel.selectedTemplate?.name : viewModel.cleanSubject,
        body: viewModel.messageBody,
        onResult: { result, _ in handleMailResult(result) }
      )
      .ignoresSafeArea()
    case .message:
      MessageComposeView(
        recipients: [context.coach.phone].compactMap { $0 },
        body: viewModel.messageBody,
        onResult: { handleMessageResult($0) }
      )
      .ignoresSafeArea()
    }
  }

  /// Log ONLY on a confirmed `.sent`. `.cancelled`/`.saved`/`.failed` log nothing.
  private func handleMailResult(_ result: MFMailComposeResult) {
    guard result == .sent else { return }
    Task {
      await viewModel.logMessageSend(.email)   // best-effort API log (Phase 3)
      await viewModel.logSend(.email)          // existing interaction log
      if viewModel.didLogSend { showSuccessToast = true }
    }
  }

  private func handleMessageResult(_ result: MessageComposeResult) {
    guard result == .sent else { return }
    Task {
      await viewModel.logMessageSend(.text)
      await viewModel.logSend(.text)
      if viewModel.didLogSend { showSuccessToast = true }
    }
  }
}

/// Compose channels that carry a template + editor. Instagram is a terminal profile-open on the
/// root screen, not a compose channel, so it's intentionally absent here.
private enum QuickCommChannel: Hashable {
  case email, text

  var templateType: TemplateType {
    self == .email ? .email : .message
  }
}

private enum QuickCommStep: Hashable {
  case template(QuickCommChannel)
  case details(QuickCommChannel)
  case completeInfo(QuickCommChannel)
  case preview(QuickCommChannel)
}

private enum QuickCommDestination: Hashable {
  case manageTemplates
}

// MARK: - Private Subviews

/// Step 1 root: recipient header + one row per available channel. Email/Text push the compose
/// wizard; Instagram opens the coach's profile directly (never templated).
private struct QuickCommChannelScreen: View {
  let recipientLine: String
  let showEmail: Bool
  let showText: Bool
  let instagramHandle: String?
  let onOpenInstagram: (URL) -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        QuickCommRecipientSection(recipientLine: recipientLine)

        if showEmail {
          NavigationLink(value: QuickCommStep.template(.email)) {
            channelRow(title: String(localized: "Send Email"), systemImage: "envelope.fill")
          }
          .accessibilityIdentifier("quickCommChannelEmail")
        }
        if showText {
          NavigationLink(value: QuickCommStep.template(.text)) {
            channelRow(title: String(localized: "Send Text"), systemImage: "message.fill")
          }
          .accessibilityIdentifier("quickCommChannelText")
        }
        if let handle = instagramHandle {
          Button {
            let clean = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle
            if let url = URL(string: "https://instagram.com/\(clean)") { onOpenInstagram(url) }
          } label: {
            channelRow(title: String(localized: "DM on Instagram"), systemImage: "camera.fill")
          }
          .accessibilityLabel(String(localized: "Open Instagram profile @\(handle)"))
          .accessibilityIdentifier("quickCommChannelInstagram")
        }
      }
      .padding()
    }
  }

  private func channelRow(title: String, systemImage: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.body)
        .foregroundStyle(Color.accentBlue)
        .frame(width: 28)
        .accessibilityHidden(true)
      Text(title)
        .font(.body.weight(.medium))
        .foregroundStyle(.primary)
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .contentShape(Rectangle())
  }
}

private struct QuickCommRecipientSection: View {
  let recipientLine: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(recipientLine)
        .font(.subheadline)
        .foregroundStyle(.primary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(uiColor: .tertiarySystemFill))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "Recipient: \(recipientLine)"))
  }
}

/// Template picker for a single channel: "None" plus that channel's templates as a flat list.
private struct QuickCommTemplateSection: View {
  let isLoading: Bool
  let templates: [CommunicationTemplate]
  let selectedTemplate: CommunicationTemplate?
  let onSelect: (CommunicationTemplate?) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Use a template")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)

      if isLoading && templates.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
      } else {
        QuickCommTemplatePicker(
          templates: templates,
          selectedTemplate: selectedTemplate,
          onSelect: onSelect
        )
      }
    }
  }
}

private struct QuickCommTemplatePicker: View {
  let templates: [CommunicationTemplate]
  let selectedTemplate: CommunicationTemplate?
  let onSelect: (CommunicationTemplate?) -> Void

  var body: some View {
    LazyVStack(spacing: 0) {
      templateOption(nil, label: String(localized: "None"))
      ForEach(templates) { template in
        templateOption(template, label: template.name)
      }
    }
    .padding(12)
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private func templateOption(_ template: CommunicationTemplate?, label: String) -> some View {
    let isSelected = selectedTemplate?.id == template?.id
    return Button {
      onSelect(template)
    } label: {
      HStack {
        Text(label)
          .font(.body)
          .foregroundStyle(.primary)
        Spacer()
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.accentBlue)
            .accessibilityHidden(true)
        }
      }
      .padding(.vertical, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    .accessibilityHint(isSelected ? "Selected" : "Select to pre-fill message")
  }
}

/// Lists the selected template's referenced variables: editable inputs for authored ones,
/// read-only rows for resolved profile values, and a "complete in your profile" hint for
/// missing profile-backed ones. Authored inputs are read-only for a parent viewing the athlete.
/// One labeled text answer on the "Complete your info" step. Multi-line (why-program /
/// why-fit) by default; `singleLine` for short values like intended major.
private struct QuickCommSpecificityField: View {
  let title: String
  let prompt: String
  @Binding var text: String
  let disabled: Bool
  var singleLine: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.subheadline.weight(.medium))
      Group {
        if singleLine {
          TextField(prompt, text: $text)
        } else {
          TextField(prompt, text: $text, axis: .vertical)
            .lineLimit(3...6)
        }
      }
      .textFieldStyle(.roundedBorder)
      .disabled(disabled)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(title)
  }
}

/// Boolean "did you complete the questionnaire?" row on the unified step. Replaces the old
/// yes/no pre-send alert; the toggle drives `commitMissingInfo` (persist on true).
private struct QuickCommQuestionnaireField: View {
  let title: String
  let prompt: String
  @Binding var completed: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.subheadline.weight(.medium))
      Toggle(isOn: $completed) {
        Text(prompt)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityIdentifier("quickCommQuestionnaireToggle")
  }
}

/// Editable subject line for email templates (reads effective, writes the VM override).
private struct QuickCommSubjectField: View {
  @Binding var subject: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Subject")
        .font(.caption)
        .foregroundStyle(.secondary)
      TextField(String(localized: "Subject"), text: $subject)
        .textFieldStyle(.roundedBorder)
        .font(.subheadline)
    }
    .accessibilityIdentifier("quickCommSubjectField")
  }
}

/// Nudge shown when the template wants stats but the athlete has none yet — opens the
/// metrics editor so a number can be added before sending.
private struct QuickCommAddMetricCTA: View {
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        Image(systemName: "chart.bar.fill")
          .foregroundStyle(Color.accentBlue)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text("Add a metric to strengthen this email")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
          Text("Coaches look for numbers — a 60 time, exit velo, etc.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.accentBlue.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("quickCommAddMetricCTA")
    .accessibilityHint("Opens the metrics editor")
  }
}

/// Editable message area (Step 2) plus, for text messages, a 160-char counter that turns red
/// when over the SMS cap. The rendered preview lives on its own screen (Step 3).
private struct QuickCommBodyEditor: View {
  @Binding var text: String
  let isTextMessage: Bool
  let characterCount: Int
  let limit: Int
  let overLimit: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Message")
        .font(.caption)
        .foregroundStyle(.secondary)
      TextEditor(text: $text)
        .font(.caption)
        .frame(minHeight: 160)
        .padding(4)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(uiColor: .separator)))
        .accessibilityIdentifier("quickCommBodyEditor")
      if isTextMessage {
        Text("\(characterCount)/\(limit)")
          .font(.caption2.monospacedDigit())
          .foregroundStyle(overLimit ? Color.errorRed : Color.secondary)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .accessibilityLabel(String(localized: "\(characterCount) of \(limit) characters"))
      }
    }
  }
}

/// Amber-highlighted, read-only render of the effective body — what the coach will see (Step 3).
private struct QuickCommBodyPreview: View {
  let preview: AttributedString
  let plainBody: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Preview — what the coach sees")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(preview)
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(String(localized: "Message preview: \(plainBody)"))
    }
  }
}

private struct QuickCommActionsSection: View {
  let showEmail: Bool
  let showText: Bool
  let coachEmail: String
  let sendDisabled: Bool
  let onSendEmail: () -> Void
  let onSendText: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Email/text sends respect the token/guardrail gate.
      Group {
        if showEmail {
          Button(action: onSendEmail) {
            Label("Send Email", systemImage: "envelope.fill")
              .font(.body.weight(.medium))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
          }
          .buttonStyle(.borderedProminent)
          .accessibilityLabel(String(localized: "Send email to \(coachEmail)"))
          .accessibilityHint("Opens Mail to compose; the message is logged only when sent")
        }

        if showText {
          Button(action: onSendText) {
            Label("Send Text", systemImage: "message.fill")
              .font(.body.weight(.medium))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
          }
          .buttonStyle(.borderedProminent)
          .accessibilityLabel(String(localized: "Send text to coach"))
          .accessibilityHint("Opens Messages to compose; the message is logged only when sent")
        }
      }
      .disabled(sendDisabled)
      .opacity(sendDisabled ? 0.5 : 1)
    }
  }
}
