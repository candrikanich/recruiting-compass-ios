import MessageUI
import SwiftUI

/// Quick Communication sheet: contact a coach with optional template, Send Email/Text, and link to Manage Templates.
struct QuickCommunicationView: View {
  let context: QuickCommunicationContext

  @State private var viewModel: QuickCommunicationViewModel
  @State private var activeComposer: ActiveComposer?
  @State private var showSuccessToast = false
  @State private var showInfoToast = false
  @State private var infoMessage: String?
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
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          QuickCommRecipientSection(recipientLine: viewModel.recipientLine)
          QuickCommTemplateSection(
            isLoading: viewModel.isLoading,
            templates: viewModel.templates,
            emailTemplates: viewModel.emailTemplates,
            textTemplates: viewModel.textTemplates,
            selectedTemplate: viewModel.selectedTemplate,
            onSelect: { viewModel.selectTemplate($0) }
          )
          if !viewModel.referencedVariables.isEmpty {
            QuickCommVariablesPanel(
              variables: viewModel.referencedVariables,
              isParent: familyManager.currentMember?.isParent == true,
              authoredBinding: { viewModel.authoredBinding(for: $0) }
            )
          }
          if viewModel.selectedTemplate?.type == .email {
            QuickCommSubjectField(subject: subjectBinding)
          }
          if viewModel.selectedTemplate != nil {
            QuickCommBodyComposeSection(
              preview: UnresolvedTokenHighlighter.attributed(
                viewModel.effectiveBody, tokenColor: .warningOrange),
              plainBody: viewModel.effectiveBody,
              text: bodyBinding,
              isTextMessage: viewModel.selectedTemplate?.type == .message,
              characterCount: viewModel.effectiveBody.count,
              limit: QuickCommunicationViewModel.textLimit,
              overLimit: viewModel.textBodyOverLimit
            )
          }
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
          QuickCommActionsSection(
            showEmail: viewModel.mailtoURL() != nil,
            showText: viewModel.smsURL() != nil,
            coachEmail: context.coach.email ?? "",
            instagramHandle: context.coach.contactInstagram,
            sendDisabled: viewModel.isSendBlocked,
            onSendEmail: handleSendEmail,
            onSendText: handleSendText,
            onOpenInstagram: { openURL($0) }
          )
        }
        .padding()
      }
      .navigationTitle("Quick Communication")
      .navigationBarTitleDisplayMode(.inline)
      .sheet(item: $activeComposer) { composer in
        composerSheet(for: composer)
      }
      .toast(isShowing: $showSuccessToast, message: $viewModel.successMessage, type: .success, duration: 3.0)
      .toast(isShowing: $showInfoToast, message: $infoMessage, type: .info, duration: 3.0)
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
        subject: viewModel.effectiveSubject.isEmpty ? viewModel.selectedTemplate?.name : viewModel.effectiveSubject,
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

private enum QuickCommDestination: Hashable {
  case manageTemplates
}

// MARK: - Private Subviews

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

private struct QuickCommTemplateSection: View {
  let isLoading: Bool
  let templates: [CommunicationTemplate]
  let emailTemplates: [CommunicationTemplate]
  let textTemplates: [CommunicationTemplate]
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
          emailTemplates: emailTemplates,
          textTemplates: textTemplates,
          selectedTemplate: selectedTemplate,
          onSelect: onSelect
        )
      }
    }
  }
}

private struct QuickCommTemplatePicker: View {
  let emailTemplates: [CommunicationTemplate]
  let textTemplates: [CommunicationTemplate]
  let selectedTemplate: CommunicationTemplate?
  let onSelect: (CommunicationTemplate?) -> Void

  var body: some View {
    LazyVStack(spacing: 0) {
      templateOption(nil, label: String(localized: "None"))
      ForEach(emailTemplates) { template in
        templateOption(template, label: template.name)
      }
      if !textTemplates.isEmpty {
        Divider().padding(.vertical, 4)
        Text("Text templates")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
        ForEach(textTemplates) { template in
          templateOption(template, label: template.name)
        }
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
private struct QuickCommVariablesPanel: View {
  let variables: [ReferencedVariable]
  let isParent: Bool
  let authoredBinding: (String) -> Binding<String>

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Fill in the details")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
      ForEach(variables) { variable in
        row(for: variable)
      }
    }
    .padding(12)
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .accessibilityIdentifier("quickCommVariablesPanel")
  }

  @ViewBuilder
  private func row(for variable: ReferencedVariable) -> some View {
    if variable.isAuthored {
      authoredRow(variable)
    } else if variable.isResolved {
      resolvedRow(variable)
    } else {
      missingRow(variable)
    }
  }

  private func authoredRow(_ variable: ReferencedVariable) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(variable.label)
        .font(.caption)
        .foregroundStyle(.secondary)
      TextField(variable.label, text: authoredBinding(variable.key), axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .disabled(isParent)
      if isParent {
        Text("Ask the athlete to fill this")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(variable.label) input"))
  }

  private func resolvedRow(_ variable: ReferencedVariable) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(variable.label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
      Text(variable.resolvedValue ?? "")
        .font(.caption.weight(.medium))
        .foregroundStyle(.primary)
        .multilineTextAlignment(.trailing)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(variable.label): \(variable.resolvedValue ?? "")"))
  }

  private func missingRow(_ variable: ReferencedVariable) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(variable.label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text("Complete in your profile")
        .font(.caption2)
        .foregroundStyle(Color.warningOrange)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(variable.label): complete in your profile"))
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

/// Amber-highlighted preview of the effective body plus an editable text area and, for text
/// messages, a 160-char counter that turns red when over the SMS cap.
private struct QuickCommBodyComposeSection: View {
  let preview: AttributedString
  let plainBody: String
  @Binding var text: String
  let isTextMessage: Bool
  let characterCount: Int
  let limit: Int
  let overLimit: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Message preview")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(preview)
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(String(localized: "Message preview: \(plainBody)"))
      TextEditor(text: $text)
        .font(.caption)
        .frame(minHeight: 120)
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

private struct QuickCommActionsSection: View {
  let showEmail: Bool
  let showText: Bool
  let coachEmail: String
  let instagramHandle: String?
  let sendDisabled: Bool
  let onSendEmail: () -> Void
  let onSendText: () -> Void
  let onOpenInstagram: (URL) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Email/text sends respect the token/guardrail gate; Instagram is a profile open, never gated.
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
          .buttonStyle(.bordered)
          .accessibilityLabel(String(localized: "Send text to coach"))
          .accessibilityHint("Opens Messages to compose; the message is logged only when sent")
        }
      }
      .disabled(sendDisabled)
      .opacity(sendDisabled ? 0.5 : 1)

      if let handle = instagramHandle {
        Button {
          let clean = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle
          if let url = URL(string: "https://instagram.com/\(clean)") { onOpenInstagram(url) }
        } label: {
          Label("Open Instagram", systemImage: "camera.fill")
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "Open Instagram profile @\(handle)"))
      }
    }
  }
}

#Preview {
  QuickCommunicationView(
    context: QuickCommunicationContext(
      coach: Coach(
        id: "1",
        firstName: "Assist",
        lastName: "Coach",
        email: "assistant.coach@wooster.edu",
        phone: "555-0123",
        position: "assistant",
        schoolId: "school-1",
        twitterHandle: nil,
        instagramHandle: nil,
        notes: nil,
        lastContactDate: nil,
        createdAt: "",
        updatedAt: ""
      ),
      schoolName: "The College of Wooster"
    )
  )
  .environment(FamilyManager.shared)
  .environment(AuthManager.shared)
}
