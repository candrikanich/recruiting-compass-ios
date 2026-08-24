import SwiftUI
import UIKit

/// Dashboard entry point for the public profile (web parity with
/// `DashboardPublicProfileLinkCard.vue`). Published → shows the shareable link with
/// Copy + Manage; not published → prompts setup. Both open the full `PublicTab` editor.
struct DashboardPublicProfileCard: View {
  @State private var vm: PublicProfileViewModel
  @State private var showEditor = false
  @State private var didCopy = false
  private let targetUserId: String?

  init(targetUserId: String?) {
    self.targetUserId = targetUserId
    _vm = State(initialValue: PublicProfileViewModel(
      service: PublicProfileServiceImpl(),
      authManager: AuthManager.shared,
      targetUserId: targetUserId,
      familyUnitId: FamilyManager.shared.familyUnitId
    ))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header

      if vm.isLoading && vm.profile == nil {
        placeholder
      } else if vm.isPublished, let url = vm.shareURL {
        publishedContent(url: url)
      } else {
        unpublishedContent
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.Surface.card)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .task { await vm.load() }
    .sheet(isPresented: $showEditor, onDismiss: { Task { await vm.load() } }) {
      NavigationStack {
        PublicTab(targetUserId: targetUserId)
          .navigationTitle("Public Profile")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button(String(localized: "Done")) { showEditor = false }
            }
          }
      }
    }
  }

  @ViewBuilder
  private var header: some View {
    HStack(spacing: 8) {
      Image(systemName: "person.crop.circle.badge.checkmark")
        .foregroundStyle(.teal)
        .accessibilityHidden(true)
      Text(String(localized: "Public Profile"))
        .font(.headline)
    }
  }

  @ViewBuilder
  private var placeholder: some View {
    RoundedRectangle(cornerRadius: 8)
      .fill(Color.Surface.border)
      .frame(height: 44)
      .redacted(reason: .placeholder)
  }

  @ViewBuilder
  private func publishedContent(url: URL) -> some View {
    Text(String(localized: "Share this link with coaches. Anyone with it can view the profile."))
      .font(.subheadline)
      .foregroundStyle(.secondary)

    Text(url.absoluteString)
      .font(.caption.monospaced())
      .foregroundStyle(.primary)
      .lineLimit(1)
      .truncationMode(.middle)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(10)
      .background(Color.Surface.border.opacity(0.35))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .accessibilityLabel(String(localized: "Public profile link"))

    HStack(spacing: 12) {
      Button {
        UIPasteboard.general.string = url.absoluteString
        didCopy = true
        Task {
          try? await Task.sleep(nanoseconds: 2_000_000_000)
          didCopy = false
        }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
            .accessibilityHidden(true)
          Text(didCopy ? String(localized: "Copied!") : String(localized: "Copy link"))
        }
        .font(.callout.weight(.semibold))
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
      }
      .buttonStyle(.borderedProminent)
      .accessibilityLabel(String(localized: "Copy public profile link"))

      Button {
        showEditor = true
      } label: {
        Text(String(localized: "Manage"))
          .font(.callout.weight(.semibold))
          .frame(maxWidth: .infinity)
          .frame(minHeight: 44)
      }
      .buttonStyle(.bordered)
    }
  }

  @ViewBuilder
  private var unpublishedContent: some View {
    Text(String(localized: "Publish a public profile to get a shareable link for coaches."))
      .font(.subheadline)
      .foregroundStyle(.secondary)

    Button {
      showEditor = true
    } label: {
      Text(String(localized: "Set up public profile"))
        .font(.callout.weight(.semibold))
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
    }
    .buttonStyle(.borderedProminent)
  }
}
