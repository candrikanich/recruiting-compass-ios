import SwiftUI

/// Quick Communication sheet: contact a coach with optional template, Send Email/Text, and link to Manage Templates.
struct QuickCommunicationView: View {
  let context: QuickCommunicationContext

  @State private var viewModel: QuickCommunicationViewModel
  @Environment(\.openURL) private var openURL
  @Environment(\.dismiss) private var dismiss

  init(context: QuickCommunicationContext) {
    self.context = context
    _viewModel = State(initialValue: QuickCommunicationViewModel(
      coach: context.coach,
      schoolName: context.schoolName
    ))
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
            mailtoURL: viewModel.mailtoURL(),
            smsURL: viewModel.smsURL(),
            coachEmail: context.coach.email ?? "",
            onOpenURL: { openURL($0) },
            onDismiss: { dismiss() }
          )
        }
        .padding()
      }
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
      .task { await viewModel.loadTemplates() }
      .accessibilityIdentifier("quickCommunicationView")
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
    .accessibilityLabel("Recipient: \(recipientLine)")
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
      templateOption(nil, label: "None")
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
    .accessibilityLabel("Message preview: \(filledBody)")
  }
}

private struct QuickCommActionsSection: View {
  let mailtoURL: URL?
  let smsURL: URL?
  let coachEmail: String
  let onOpenURL: (URL) -> Void
  let onDismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let mailto = mailtoURL {
        Button {
          onOpenURL(mailto)
          onDismiss()
        } label: {
          Label("Send Email", systemImage: "envelope.fill")
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Send email to \(coachEmail)")
        .accessibilityHint("Opens Mail with recipient and optional message body")
      }

      if let sms = smsURL {
        Button {
          onOpenURL(sms)
          onDismiss()
        } label: {
          Label("Send Text", systemImage: "message.fill")
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "Send text to coach"))
        .accessibilityHint("Opens Messages with optional message body")
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
}
