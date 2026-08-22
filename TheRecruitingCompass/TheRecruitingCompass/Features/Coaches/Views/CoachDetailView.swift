import MessageUI
import SwiftUI

private struct ShareURL: Identifiable {
  let id = UUID()
  let url: URL
}

/// Identifies which in-app composer to present for a Send Profile, carrying the
/// resolved message so the result handler can log the send.
private struct ProfileComposerContext: Identifiable {
  let id = UUID()
  let channel: SendProfileChannel
  let message: SendProfileMessage
}

struct CoachDetailView: View {
  let coachId: String
  let allCoaches: [Coach]
  let allSchools: [School]

  @State private var viewModel: CoachDetailViewModel
  @State private var quickCommunicationContext: QuickCommunicationContext?
  @State private var sendProfileVM = SendProfileViewModel(
    service: PublicProfileServiceImpl(),
    authManager: AuthManager.shared
  )
  @State private var shareItem: ShareURL?
  @State private var profileComposer: ProfileComposerContext?
  @State private var pendingChannelChoice: SendProfileMessage?
  @State private var linkCopied = false
  @Environment(\.sizeCategory) private var sizeCategory
  @Environment(\.dismiss) private var dismiss

  init(coachId: String, allCoaches: [Coach] = [], allSchools: [School] = []) {
    self.coachId = coachId
    self.allCoaches = allCoaches
    self.allSchools = allSchools
    _viewModel = State(initialValue: CoachDetailViewModel(
      coachId: coachId,
      allCoaches: allCoaches,
      allSchools: allSchools
    ))
  }

  var body: some View {
    ScrollView {
      if viewModel.isLoading {
        LoadingStateView(message: "Loading coach details")
          .padding(.top, 100)
      } else if let coach = viewModel.coach {
        detailContent(coach: coach)
      } else if let error = viewModel.errorMessage {
        InlineErrorView(message: error)
          .padding(.top, 100)
      }
    }
    .navigationTitle("Coach Details")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.hidden, for: .tabBar)
    .toolbar {
      ToolbarItem(placement: .principal) {
        SaveStatusView(status: viewModel.saveStatus)
      }
      ToolbarItem(placement: .primaryAction) {
        Menu {
          Button {
            if let coach = viewModel.coach {
              quickCommunicationContext = QuickCommunicationContext(
                coach: coach,
                schoolName: viewModel.school?.name
              )
            }
          } label: {
            Label("Quick Communication", systemImage: "envelope.badge")
          }
          .disabled(viewModel.isLoading || viewModel.coach == nil)

          Button {
            viewModel.startEditing()
          } label: {
            Label("Edit", systemImage: "pencil")
          }
          .disabled(viewModel.isLoading || viewModel.isSaving)

          Button(role: .destructive) {
            viewModel.confirmDelete()
          } label: {
            Label("Delete", systemImage: "trash")
          }
          .disabled(viewModel.isLoading || viewModel.isDeleting)
        } label: {
          Image(systemName: "ellipsis.circle")
            .accessibilityLabel(String(localized: "Coach actions menu"))
        }
      }
    }
    .sensoryFeedback(.success, trigger: viewModel.hapticSuccessTrigger)
    .sheet(isPresented: $viewModel.isEditing) {
      if viewModel.editedCoach != nil {
        CoachEditForm(
          editedCoach: viewModel.editableCoachBinding,
          validationErrors: viewModel.validationErrors,
          isSaving: viewModel.isSaving,
          onSave: { await viewModel.saveChanges() },
          onCancel: { viewModel.cancelEditing() }
        )
      }
    }
    .sheet(item: $quickCommunicationContext) { context in
      QuickCommunicationView(context: context)
    }
    .sheet(item: $shareItem) { item in
      ActivityShareSheet(activityItems: [item.url])
    }
    .sheet(item: $profileComposer) { context in
      profileComposerSheet(context)
    }
    .confirmationDialog(
      "Send Profile",
      isPresented: channelChoiceBinding,
      titleVisibility: .visible,
      presenting: pendingChannelChoice
    ) { message in
      if let email = message.coachEmail {
        Button("Email \(email)") { presentComposer(.email, message) }
      }
      if let phone = message.coachPhone {
        Button("Text \(phone)") { presentComposer(.text, message) }
      }
      Button("Cancel", role: .cancel) {}
    } message: { _ in
      Text("How would you like to send this profile?")
    }
    .alert(
      "Profile Not Published",
      isPresented: $sendProfileVM.notPublishedPrompt
    ) {
      Button("OK") { sendProfileVM.notPublishedPrompt = false }
    } message: {
      Text("Publish your profile before sending it to a coach.")
    }
    .confirmationDialog("Delete Coach", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
      Button("Delete", role: .destructive) {
        Task {
          await viewModel.deleteCoach()
          if viewModel.deleteSuccessMessage != nil {
            dismiss()
          }
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Are you sure you want to delete this coach? This action cannot be undone.")
    }
    .refreshable {
      await viewModel.loadDetails()
    }
    .task {
      await viewModel.loadCoach()
      await viewModel.loadDetails()
      await sendProfileVM.loadTrackingInfo(for: coachId)
    }
  }

  // MARK: - Content

  private func detailContent(coach: Coach) -> some View {
    VStack(alignment: .leading, spacing: 24) {
      CoachDetailHeader(coach: coach, school: viewModel.school)
      ContactInfoSection(
        coach: coach,
        onEmailTap: {
          quickCommunicationContext = QuickCommunicationContext(coach: coach, schoolName: viewModel.school?.name)
        },
        onPhoneTap: {
          quickCommunicationContext = QuickCommunicationContext(coach: coach, schoolName: viewModel.school?.name)
        }
      )

      if let stats = viewModel.stats {
        CoachStatsGrid(stats: stats)
      }

      CoachStatisticsSection(coach: coach)
      sendProfileSection(coach: coach)
      recentInteractionsSection
      sharedNotesSection
    }
    .padding()
  }

  /// Only offered once the profile is published — an unpublished profile has
  /// nothing shareable, so the action is hidden rather than shown-then-blocked.
  /// Once a link exists for this coach, also offers copy-link + view stats
  /// (parity with the web coach page).
  @ViewBuilder
  private func sendProfileSection(coach: Coach) -> some View {
    if sendProfileVM.isPublished {
      VStack(alignment: .leading, spacing: 8) {
        Button {
          startSendProfile(coach: coach)
        } label: {
          Label("Send Profile", systemImage: "square.and.arrow.up")
            .font(.body)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "Send Profile"))

        if sendProfileVM.trackingURL != nil {
          profileLinkStats
        }
      }
    }
  }

  @ViewBuilder
  private var profileLinkStats: some View {
    if let count = sendProfileVM.viewCount {
      Text("Viewed \(count) \(count == 1 ? "time" : "times")")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    Button {
      sendProfileVM.copyTrackingLink()
      linkCopied = true
      Task {
        try? await Task.sleep(for: .seconds(2))
        linkCopied = false
      }
    } label: {
      Label(
        linkCopied ? "Copied" : "Copy Link",
        systemImage: linkCopied ? "checkmark" : "doc.on.doc"
      )
      .font(.caption)
    }
    .buttonStyle(.borderless)
    .accessibilityLabel(String(localized: "Copy profile link"))
  }

  private var channelChoiceBinding: Binding<Bool> {
    Binding(
      get: { pendingChannelChoice != nil },
      set: { if !$0 { pendingChannelChoice = nil } }
    )
  }

  /// Resolve the profile URL + boilerplate, then route to the matching channel.
  private func startSendProfile(coach: Coach) {
    Task {
      switch await sendProfileVM.prepare(for: coach) {
      case let .email(message): presentComposer(.email, message)
      case let .text(message): presentComposer(.text, message)
      case let .choice(message): pendingChannelChoice = message
      case let .share(url): shareItem = ShareURL(url: url)
      case .notPublished, .failed: break  // notPublished alert is bound to the VM
      }
    }
  }

  /// Present the in-app composer when the device can send; otherwise fall back to
  /// the system share sheet (and log nothing — an external hand-off can't confirm).
  private func presentComposer(_ channel: SendProfileChannel, _ message: SendProfileMessage) {
    switch channel {
    case .email:
      if MFMailComposeViewController.canSendMail() {
        profileComposer = ProfileComposerContext(channel: .email, message: message)
      } else {
        shareItem = ShareURL(url: message.url)
      }
    case .text:
      if MFMessageComposeViewController.canSendText() {
        profileComposer = ProfileComposerContext(channel: .text, message: message)
      } else {
        shareItem = ShareURL(url: message.url)
      }
    }
  }

  /// Log ONLY on a confirmed `.sent`; cancel/save/fail record nothing.
  @ViewBuilder
  private func profileComposerSheet(_ context: ProfileComposerContext) -> some View {
    switch context.channel {
    case .email:
      MailComposeView(
        recipients: [context.message.coachEmail].compactMap { $0 },
        subject: context.message.subject,
        body: context.message.emailBody,
        onResult: { result, _ in
          guard result == .sent else { return }
          Task { await sendProfileVM.logSend(.email, message: context.message) }
        }
      )
      .ignoresSafeArea()
    case .text:
      MessageComposeView(
        recipients: [context.message.coachPhone].compactMap { $0 },
        body: context.message.textBody,
        onResult: { result in
          guard result == .sent else { return }
          Task { await sendProfileVM.logSend(.text, message: context.message) }
        }
      )
      .ignoresSafeArea()
    }
  }

  @ViewBuilder
  private var recentInteractionsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Recent Interactions")

      if viewModel.recentInteractions.isEmpty {
        Text("No interactions yet")
          .font(.body)
          .foregroundStyle(.secondary)
          .italic()
          .padding(.vertical, 8)
      } else {
        VStack(spacing: 0) {
          ForEach(viewModel.recentInteractions) { interaction in
            RecentInteractionRow(interaction: interaction)
            if interaction.id != viewModel.recentInteractions.last?.id {
              Divider()
                .padding(.vertical, 4)
                .accessibilityHidden(true)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var sharedNotesSection: some View {
    NotesSection(
      title: String(localized: "Shared Notes"),
      notes: $viewModel.editedSharedNotes,
      onBlur: { await viewModel.saveSharedNotes() }
    )
  }

}

#Preview {
  NavigationStack {
    CoachDetailView(
      coachId: "1",
      allCoaches: [
        Coach(
          id: "1",
          firstName: "John",
          lastName: "Smith",
          email: "john@university.edu",
          phone: "555-0123",
          position: "head",
          schoolId: "school-1",
          twitterHandle: "@coachsmith",
          instagramHandle: "@coachsmith",
          notes: "Great recruiter, very responsive",
          lastContactDate: "2026-01-15T10:00:00Z",
          createdAt: "2025-01-01T00:00:00Z",
          updatedAt: "2026-01-15T10:00:00Z"
        )
      ],
      allSchools: [
        School(
          id: "school-1",
          userId: "user-1",
          name: "State University",
          location: "State College, PA",
          city: "State College",
          state: "PA",
          division: "D1",
          conference: "Big Ten",
          ranking: 25,
          isFavorite: false,
          website: nil,
          faviconUrl: nil,
          twitterHandle: nil,
          instagramHandle: nil,
          ncaaId: nil,
          status: "interested",
          statusChangedAt: nil,
          notes: nil,
          pros: [],
          cons: [],
          offerDetails: nil,
          academicInfo: nil,
          amenities: nil,
          coachingPhilosophy: nil,
          coachingStyle: nil,
          recruitingApproach: nil,
          communicationStyle: nil,
          successMetrics: nil,
          familyUnitId: "family-1",
          createdBy: nil,
          updatedBy: nil,
          createdAt: "2025-01-01T00:00:00Z",
          updatedAt: "2025-01-01T00:00:00Z"
        )
      ]
    )
  }
}
