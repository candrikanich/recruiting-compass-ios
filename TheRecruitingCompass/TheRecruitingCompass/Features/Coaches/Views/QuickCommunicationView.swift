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
          recipientSection
          templateSection
          if viewModel.selectedTemplate != nil, !viewModel.filledBody.isEmpty {
            bodyPreviewSection
          }
          actionsSection
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
          NavigationLink {
            CommunicationTemplatesView()
          } label: {
            Text("Manage Templates")
          }
        }
      }
      .task { await viewModel.loadTemplates() }
      .accessibilityIdentifier("quickCommunicationView")
    }
  }

  private var recipientSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(viewModel.recipientLine)
        .font(.subheadline)
        .foregroundStyle(.primary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(uiColor: .tertiarySystemFill))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Recipient: \(viewModel.recipientLine)")
  }

  private var templateSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Use a template")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)

      if viewModel.isLoading && viewModel.templates.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
      } else {
        templatePicker
      }
    }
  }

  private var templatePicker: some View {
    VStack(spacing: 0) {
      templateOption(nil, label: "None")
      ForEach(viewModel.emailTemplates) { template in
        templateOption(template, label: template.name)
      }
      if !viewModel.textTemplates.isEmpty {
        Divider().padding(.vertical, 4)
        Text("Text templates")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
        ForEach(viewModel.textTemplates) { template in
          templateOption(template, label: template.name)
        }
      }
    }
    .padding(12)
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private func templateOption(_ template: CommunicationTemplate?, label: String) -> some View {
    let isSelected = viewModel.selectedTemplate?.id == template?.id
    return Button {
      viewModel.selectTemplate(template)
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

  private var bodyPreviewSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Message preview")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(viewModel.filledBody)
        .font(.caption)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Message preview: \(viewModel.filledBody)")
  }

  private var actionsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      if viewModel.mailtoURL() != nil {
        Button {
          if let url = viewModel.mailtoURL() {
            openURL(url)
            dismiss()
          }
        } label: {
          Label("Send Email", systemImage: "envelope.fill")
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Send email to \(context.coach.email ?? "")")
        .accessibilityHint("Opens Mail with recipient and optional message body")
      }

      if viewModel.smsURL() != nil {
        Button {
          if let url = viewModel.smsURL() {
            openURL(url)
            dismiss()
          }
        } label: {
          Label("Send Text", systemImage: "message.fill")
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Send text to coach")
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
        privateNotes: nil,
        responsivenessScore: 0,
        lastContactDate: nil,
        createdAt: "",
        updatedAt: ""
      ),
      schoolName: "The College of Wooster"
    )
  )
}
