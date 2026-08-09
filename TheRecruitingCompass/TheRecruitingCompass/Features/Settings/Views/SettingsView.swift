import SwiftUI

private enum SettingsDestination: Hashable {
  case familyManagement
  case profile
  case homeLocation
  case playerDetails
  case schoolPreferences
  case dashboardCustomization
  case notificationPreferences
  case communicationTemplates
  case videoLinks
  case about
}

struct SettingsView: View {
  @Environment(AuthManager.self) private var authManager
  @Environment(FamilyManager.self) private var familyManager
  @State private var presentedLegal: LegalDocument?
  @State private var showCodeCopied = false
  @State private var viewModel: SettingsViewModel

  private let preferenceService: PreferenceManaging

  init(preferenceService: PreferenceManaging = PreferenceServiceImpl(supabaseManager: .shared)) {
    self.preferenceService = preferenceService
    _viewModel = State(initialValue: SettingsViewModel(preferenceService: preferenceService))
  }

  var body: some View {
    List {
        // Family Section (code when available + Family Management)
        Section {
          if let code = familyManager.familyUnit?.familyCode {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("Family code")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text(code)
                  .font(.system(.body, design: .monospaced).weight(.medium))
                  .tracking(1)
              }
              Spacer()
              Button {
                UIPasteboard.general.string = code
                showCodeCopied = true
                Task {
                  try? await Task.sleep(for: .seconds(2))
                  showCodeCopied = false
                }
              } label: {
                Text(showCodeCopied ? String(localized: "Copied!") : String(localized: "Copy"))
                  .font(.caption.weight(.medium))
              }
              .buttonStyle(.bordered)
              .disabled(showCodeCopied)
              .accessibilityLabel(showCodeCopied ? String(localized: "Copied to clipboard") : String(localized: "Copy family code"))
            }
            .padding(.vertical, 4)
          }

          NavigationLink(value: SettingsDestination.familyManagement) {
            SettingsRow(
              icon: "person.3.fill",
              title: String(localized: "Family Management"),
              description: String(localized: "Manage family members and share recruiting data"),
              color: .red
            )
          }
        } header: {
          Text("Family")
        }

        // Player Info Section
        Section {
          NavigationLink(value: SettingsDestination.homeLocation) {
            SettingsRow(
              icon: "house.fill",
              title: String(localized: "Home Location"),
              description: String(localized: "Set your home address to calculate distances to schools"),
              color: .blue,
              badgeStatus: viewModel.homeLocationStatus
            )
          }

          NavigationLink(value: SettingsDestination.playerDetails) {
            SettingsRow(
              icon: "person.fill",
              title: String(localized: "Player Details"),
              description: String(localized: "Graduation year, positions, stats, and athletic profile"),
              color: .green,
              badgeStatus: viewModel.playerDetailsStatus
            )
          }

          NavigationLink(value: SettingsDestination.videoLinks) {
            SettingsRow(
              icon: "play.rectangle.fill",
              title: String(localized: "Video Links"),
              description: String(localized: "Highlight and film links coaches can watch"),
              color: .blue
            )
          }
        } header: {
          Text("Player Info")
        }

        // School Preferences Section
        Section {
          NavigationLink(value: SettingsDestination.schoolPreferences) {
            SettingsRow(
              icon: "target",
              title: String(localized: "School Preferences"),
              description: String(localized: "Set criteria for finding your ideal schools"),
              color: .purple,
              badgeStatus: viewModel.schoolPreferencesStatus
            )
          }
        } header: {
          Text("School Preferences")
        }

        // Dashboard Section
        Section {
          NavigationLink(value: SettingsDestination.dashboardCustomization) {
            SettingsRow(
              icon: "slider.horizontal.3",
              title: String(localized: "Dashboard Customization"),
              description: String(localized: "Show or hide dashboard widgets"),
              color: .blue
            )
          }
        } header: {
          Text("Dashboard")
        }

        // Communication & Social Section
        Section {
          NavigationLink(value: SettingsDestination.notificationPreferences) {
            SettingsRow(
              icon: "bell.fill",
              title: String(localized: "Notifications"),
              description: String(localized: "Configure alerts for follow-ups, deadlines, and updates"),
              color: .orange
            )
          }

          NavigationLink(value: SettingsDestination.communicationTemplates) {
            SettingsRow(
              icon: "doc.text.fill",
              title: String(localized: "Communication Templates"),
              description: String(localized: "Create and manage email, text, and social media templates"),
              color: .accentBlue
            )
          }
        } header: {
          Text("Communication & Social")
        }

        // User Settings Section
        Section {
          NavigationLink(value: SettingsDestination.profile) {
            SettingsRow(
              icon: "person.circle.fill",
              title: String(localized: "User Settings"),
              description: String(localized: "Photo, name, email, password, and account settings"),
              color: .blue
            )
          }
        } header: {
          Text("User Settings")
        }

        // Legal Section
        Section {
          Button {
            presentedLegal = .termsOfService
          } label: {
            SettingsRow(
              icon: "doc.text",
              title: String(localized: "Terms of Service"),
              description: String(localized: "Read the terms and conditions for using the app"),
              color: .iconGray
            )
          }
          .buttonStyle(.plain)

          Button {
            presentedLegal = .privacyPolicy
          } label: {
            SettingsRow(
              icon: "hand.raised",
              title: String(localized: "Privacy Policy"),
              description: String(localized: "How we collect, use, and protect your data"),
              color: .iconGray
            )
          }
          .buttonStyle(.plain)
        } header: {
          Text("Legal")
        }

        // App Section
        Section {
          NavigationLink(value: SettingsDestination.about) {
            SettingsRow(
              icon: "info.circle.fill",
              title: String(localized: "About & Feedback"),
              description: String(localized: "Our mission, and a way to send us feedback or report issues"),
              color: .iconGray
            )
          }
        } header: {
          Text("App")
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(for: SettingsDestination.self) { destination in
        switch destination {
        case .familyManagement:
          FamilyManagementView()
        case .profile:
          ProfileView(preferenceService: preferenceService)
        case .homeLocation:
          HomeLocationView(
            preferenceService: preferenceService,
            targetUserId: familyManager.selectedAthlete?.userId ?? authManager.user?.id
          )
        case .playerDetails:
          PlayerDetailsView(
            preferenceService: preferenceService,
            userRole: authManager.user?.role ?? .player,
            targetUserId: familyManager.selectedAthlete?.userId ?? authManager.user?.id
          )
        case .schoolPreferences:
          SchoolPreferencesView(
            preferenceService: preferenceService,
            targetUserId: familyManager.selectedAthlete?.userId ?? authManager.user?.id
          )
        case .dashboardCustomization:
          DashboardCustomizationView(preferenceService: preferenceService)
        case .notificationPreferences:
          NotificationPreferencesView(preferenceService: preferenceService)
        case .communicationTemplates:
          CommunicationTemplatesView()
        case .videoLinks:
          VideoLinksEditorView(
            athleteUserId: familyManager.selectedAthlete?.userId ?? authManager.user?.id ?? "",
            familyUnitId: familyManager.currentMember?.familyUnitId,
            isReadOnly: familyManager.currentMember?.isParent == true
          )
        case .about:
          AboutView()
        }
      }
      .task {
        await familyManager.loadFamilyData()
        await viewModel.loadCompletionStatus()
      }
      .sheet(item: $presentedLegal) { doc in
        doc.view
      }
  }
}

// MARK: - Settings Row Component
private struct SettingsRow: View {
  let icon: String
  let title: String
  let description: String
  let color: Color
  var badgeStatus: SettingsBadgeStatus?

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundStyle(.white)
        .frame(width: 36, height: 36)
        .background(color)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(title)
            .font(.body)
            .fontWeight(.medium)
            .foregroundStyle(.primary)

          if let status = badgeStatus {
            HStack(spacing: 3) {
              Image(systemName: status.iconName)
                .font(.caption2)
                .accessibilityHidden(true)
              Text(status.label)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(status.foregroundColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.backgroundColor)
            .clipShape(Capsule())
          }
        }

        Text(description)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
        badgeStatus.map { String(localized: "\(title): \($0.label). \(description)") }
            ?? String(localized: "\(title): \(description)")
    )
  }
}

// MARK: - Preview
#Preview {
  SettingsView()
    .environment(AuthManager.shared)
    .environment(FamilyManager.shared)
}
