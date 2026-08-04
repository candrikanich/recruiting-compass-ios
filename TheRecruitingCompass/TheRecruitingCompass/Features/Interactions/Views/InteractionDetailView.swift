import SwiftUI

private enum InteractionDetailDestination: Hashable {
  case school(id: String)
  case coach(id: String)
}

struct InteractionDetailView: View {
  @State private var viewModel: InteractionDetailViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var hapticSuccessTrigger = 0
  @State private var hapticErrorTrigger = 0
  @State private var hapticWarningTrigger = 0

  init(
    interactionId: String,
    familyUnitId: String,
    interactionsService: InteractionsManaging? = nil,
    authManager: AuthManaging? = nil
  ) {
    let service = interactionsService ?? InteractionsServiceImpl(supabaseManager: SupabaseManager.shared)
    let auth = authManager ?? AuthManager.shared

    _viewModel = State(initialValue: InteractionDetailViewModel(
      interactionId: interactionId,
      familyUnitId: familyUnitId,
      interactionsService: service,
      authManager: auth
    ))
  }

  var body: some View {
    ScrollView {
      if viewModel.isLoading {
        LoadingStateView(message: "Loading interaction...")
          .padding(.top, 100)
      } else if let interaction = viewModel.interaction {
        detailContent(interaction: interaction)
      } else if viewModel.errorMessage != nil {
        InlineErrorView(message: viewModel.errorMessage ?? "Interaction not found")
          .padding(.top, 100)
      }
    }
    .navigationTitle("Interaction")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(for: InteractionDetailDestination.self) { destination in
      switch destination {
      case .school(let id):
        SchoolDetailView(schoolId: id)
      case .coach(let id):
        CoachDetailView(coachId: id)
      }
    }
    .toolbar(.hidden, for: .tabBar)
    .toolbar {
      if viewModel.canExport || viewModel.canDelete {
        ToolbarItem(placement: .primaryAction) {
          Menu {
            if viewModel.canExport {
              ShareLink(
                item: viewModel.exportInteraction(),
                subject: Text("Interaction: \(viewModel.displaySubject)")
              ) {
                Label("Export", systemImage: "square.and.arrow.up")
              }
            }

            if viewModel.canDelete {
              Button(role: .destructive) {
                viewModel.confirmDelete()
              } label: {
                Label("Delete", systemImage: "trash")
              }
              .disabled(viewModel.isDeleting)
            }
          } label: {
            Image(systemName: "ellipsis.circle")
              .accessibilityLabel("Interaction actions menu")
          }
        }
      }
    }
    .confirmationDialog(
      "Delete Interaction",
      isPresented: $viewModel.showDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        Task {
          hapticWarningTrigger += 1
          let success = await viewModel.deleteInteraction()
          if success {
            hapticSuccessTrigger += 1
            dismiss()
          } else {
            hapticErrorTrigger += 1
          }
        }
      }
      Button("Cancel", role: .cancel) {
        viewModel.cancelDelete()
      }
    } message: {
      Text("Are you sure you want to delete this interaction? This action cannot be undone.")
    }
    .task {
      await viewModel.loadInteraction()
    }
    .sensoryFeedback(.success, trigger: hapticSuccessTrigger)
    .sensoryFeedback(.error, trigger: hapticErrorTrigger)
    .sensoryFeedback(.warning, trigger: hapticWarningTrigger)
  }

  // MARK: - Detail Content

  @ViewBuilder
  private func detailContent(interaction: Interaction) -> some View {
    VStack(alignment: .leading, spacing: 24) {
      headerSection(interaction: interaction)
      badgesSection(interaction: interaction)

      if viewModel.hasContent {
        contentSection(interaction: interaction)
      }

      detailsGrid
      metadataSection(interaction: interaction)
    }
    .padding()
  }

  // MARK: - Header Section

  private func headerSection(interaction: Interaction) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(viewModel.displaySubject)
        .font(.title2)
        .bold()
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("interaction-subject")

      Text(viewModel.formattedDate)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Occurred at \(viewModel.formattedDate)")
    }
  }

  // MARK: - Badges Section

  private func badgesSection(interaction: Interaction) -> some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        // Type badge — always blue per design system
        BadgeView(
          text: interaction.type.displayName,
          color: interaction.type.badgeColor,
          icon: interaction.type.iconName,
          accessibilityLabel: "\(interaction.type.displayName) interaction"
        )

        // Direction badge
        BadgeView(
          text: interaction.direction.displayName,
          color: interaction.direction.badgeColor,
          accessibilityLabel: "\(interaction.direction.displayName) direction"
        )

        // Sentiment badge
        if let sentiment = interaction.sentiment {
          BadgeView(
            text: sentiment.displayName,
            color: sentiment.badgeColor,
            accessibilityLabel: "Sentiment: \(sentiment.displayName)"
          )
        }
      }
    }
    .scrollIndicators(.hidden)
  }

  // MARK: - Content Section

  private func contentSection(interaction: Interaction) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Content")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      if let content = interaction.content {
        Text(content)
          .font(.body)
          .textSelection(.enabled)
          .accessibilityLabel("Interaction content")
      }
    }
    .padding()
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 12))
  }

  // MARK: - Details Grid

  @ViewBuilder
  private var detailsGrid: some View {
    VStack(spacing: 16) {
      Text("Details")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)

      LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible())
      ], spacing: 16) {
        // School - tappable if present
        if let school = viewModel.school {
          NavigationLink(value: InteractionDetailDestination.school(id: school.id)) {
            DetailGridItem(
              title: "School",
              value: school.name,
              icon: "building.2",
              isTappable: true
            )
          }
          .buttonStyle(.plain)
          .accessibilityLabel("School: \(school.name), tap to view details")
        } else {
          DetailGridItem(
            title: "School",
            value: "—",
            icon: "building.2",
            isTappable: false
          )
        }

        // Coach - tappable if present
        if let coach = viewModel.coach {
          NavigationLink(value: InteractionDetailDestination.coach(id: coach.id)) {
            DetailGridItem(
              title: "Coach",
              value: "\(coach.firstName) \(coach.lastName)",
              icon: "person",
              isTappable: true
            )
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Coach: \(coach.firstName) \(coach.lastName), tap to view details")
        } else {
          DetailGridItem(
            title: "Coach",
            value: "—",
            icon: "person",
            isTappable: false
          )
        }

        // Event - not yet implemented
        DetailGridItem(
          title: "Event",
          value: "—",
          icon: "calendar",
          isTappable: false
        )

        // Logged By - not tappable
        DetailGridItem(
          title: "Logged By",
          value: viewModel.loggedByDisplay,
          icon: "person.circle",
          isTappable: false
        )
      }
    }
    .padding()
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 12))
  }

  // MARK: - Metadata Section

  private func metadataSection(interaction: Interaction) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Created: \(formatMetadataDate(interaction.createdAt))")
        .font(.caption)
        .foregroundStyle(.secondary)

      if viewModel.hasAttachments {
        Text("Attachments: \(viewModel.interaction?.attachmentCount ?? 0)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Helper Methods

  private static let isoFormatter = ISO8601DateFormatter()

  private func formatMetadataDate(_ isoString: String) -> String {
    guard let date = Self.isoFormatter.date(from: isoString) else {
      return isoString
    }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}
