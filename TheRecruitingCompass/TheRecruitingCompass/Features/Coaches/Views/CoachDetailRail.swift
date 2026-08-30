import SwiftUI

/// Left-rail identity + quick-action sections for coach detail on regular width
/// (avatar/name/school, direct channels, notes, tags, profile meta), matching web's
/// coach-page left rail. Stacks above the main content on compact width via
/// `AdaptiveDetailLayout`.
struct CoachDetailRail: View {
  let coach: Coach
  @Bindable var viewModel: CoachDetailViewModel
  let onEdit: () -> Void
  let onDelete: () -> Void
  let onEmail: () -> Void
  let onText: () -> Void
  let onCall: () -> Void
  let onTwitter: () -> Void
  let onInstagram: () -> Void
  let onLog: () -> Void

  var body: some View {
  VStack(alignment: .leading, spacing: 16) {
    SectionCard {
    CoachDetailHeader(coach: coach, school: viewModel.school, onEdit: onEdit, onDelete: onDelete)
    }

    SectionCard(label: "Direct Channels") {
    CoachDirectChannelsGrid(
      coach: coach,
      onEmail: onEmail,
      onText: onText,
      onCall: onCall,
      onTwitter: onTwitter,
      onInstagram: onInstagram,
      onLog: onLog
    )
    }

    SectionCard(label: "Internal Notes") {
    NotesSection(
      title: String(localized: "Shared Notes"),
      notes: $viewModel.editedSharedNotes,
      onBlur: { await viewModel.saveSharedNotes() }
    )
    }

    SectionCard(label: "Tags") {
    CoachTagsCard(
      tags: coach.tags,
      onAdd: { tag in Task { await viewModel.saveTags(coach.tags + [tag]) } },
      onRemove: { tag in Task { await viewModel.saveTags(coach.tags.filter { $0 != tag }) } }
    )
    }

    SectionCard(label: "Profile Meta") { CoachProfileMetaCard(coach: coach) }
  }
  }
}
