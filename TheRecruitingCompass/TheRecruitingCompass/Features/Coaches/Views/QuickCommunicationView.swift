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
          if viewModel.selectedTemplate != nil, !viewModel.filledBody.isEmpty {
            QuickCommBodyPreviewSection(filledBody: viewModel.filledBody)
          }
          QuickCommActionsSection(
            showEmail: viewModel.mailtoURL() != nil,
            showText: viewModel.smsURL() != nil,
            coachEmail: context.coach.email ?? "",
            onSendEmail: handleSendEmail,
            onSendText: handleSendText
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
          athleteUserId: familyManager.selectedAthlete?.userId
        )
        await viewModel.loadTemplates()
        await viewModel.loadVideoLinks()
      }
      .accessibilityIdentifier("quickCommunicationView")
    }
  }

  // MARK: - Send handling

  /// Present the in-app mail composer when the device can send mail; otherwise fall back to the
  /// `mailto:` hand-off and log NOTHING (an external hand-off can't confirm the send).
  private func handleSendEmail() {
    if MFMailComposeViewController.canSendMail() {
      activeComposer = .mail
    } else if let url = viewModel.mailtoURL() {
      openURL(url)
      infoMessage = String(localized: "Log it from Interactions once sent.")
      showInfoToast = true
    }
  }

  /// Present the in-app message composer when the device can send texts; otherwise fall back to the
  /// `sms:` hand-off and log NOTHING.
  private func handleSendText() {
    if MFMessageComposeViewController.canSendText() {
      activeComposer = .message
    } else if let url = viewModel.smsURL() {
      openURL(url)
      infoMessage = String(localized: "Log it from Interactions once sent.")
      showInfoToast = true
    }
  }

  @ViewBuilder
  private func composerSheet(for composer: ActiveComposer) -> some View {
    switch composer {
    case .mail:
      MailComposeView(
        recipients: [context.coach.email].compactMap { $0 },
        subject: viewModel.selectedTemplate?.name,
        body: viewModel.filledBody,
        onResult: { result, _ in handleMailResult(result) }
      )
      .ignoresSafeArea()
    case .message:
      MessageComposeView(
        recipients: [context.coach.phone].compactMap { $0 },
        body: viewModel.filledBody,
        onResult: { handleMessageResult($0) }
      )
      .ignoresSafeArea()
    }
  }

  /// Log ONLY on a confirmed `.sent`. `.cancelled`/`.saved`/`.failed` log nothing.
  private func handleMailResult(_ result: MFMailComposeResult) {
    guard result == .sent else { return }
    Task {
      await viewModel.logSend(.email)
      if viewModel.didLogSend { showSuccessToast = true }
    }
  }

  private func handleMessageResult(_ result: MessageComposeResult) {
    guard result == .sent else { return }
    Task {
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

private struct QuickCommBodyPreviewSection: View {
  let filledBody: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Message preview")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(filledBody)
        .font(.caption)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "Message preview: \(filledBody)"))
  }
}

private struct QuickCommActionsSection: View {
  let showEmail: Bool
  let showText: Bool
  let coachEmail: String
  let onSendEmail: () -> Void
  let onSendText: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
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
