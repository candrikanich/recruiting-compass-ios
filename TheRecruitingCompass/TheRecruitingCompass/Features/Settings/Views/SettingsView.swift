import SwiftUI

struct SettingsView: View {
  @Environment(AuthManager.self) private var authManager
  @Environment(FamilyManager.self) private var familyManager
  @State private var presentedLegal: LegalDocument?
  @State private var showCodeCopied = false

  private let preferenceService: PreferenceManaging

  init(preferenceService: PreferenceManaging = PreferenceServiceImpl(supabaseManager: .shared)) {
    self.preferenceService = preferenceService
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
                  .foregroundColor(.secondary)
                Text(code)
                  .font(.system(.body, design: .monospaced).weight(.medium))
                  .tracking(1)
              }
              Spacer()
              Button {
                UIPasteboard.general.string = code
                showCodeCopied = true
                Task {
                  try? await Task.sleep(nanoseconds: 2_000_000_000)
                  await MainActor.run { showCodeCopied = false }
                }
              } label: {
                Text(showCodeCopied ? "Copied!" : "Copy")
                  .font(.caption.weight(.medium))
              }
              .buttonStyle(.bordered)
              .disabled(showCodeCopied)
              .accessibilityLabel(showCodeCopied ? "Copied to clipboard" : "Copy family code")
            }
            .padding(.vertical, 4)
          }

          NavigationLink {
            FamilyManagementView()
          } label: {
            SettingsRow(
              icon: "person.3.fill",
              title: "Family Management",
              description: "Manage family members and share recruiting data",
              color: .red
            )
          }
        } header: {
          Text("Family")
        }

        // Profile & Player Info Section
        Section {
          NavigationLink {
            HomeLocationView(preferenceService: preferenceService)
          } label: {
            SettingsRow(
              icon: "house.fill",
              title: "Home Location",
              description: "Set your home address to calculate distances to schools",
              color: .blue
            )
          }

          NavigationLink {
            PlayerDetailsView(
              preferenceService: preferenceService,
              userRole: authManager.user?.role ?? .player
            )
          } label: {
            SettingsRow(
              icon: "person.fill",
              title: "Player Details",
              description: "Graduation year, positions, stats, and athletic profile",
              color: .green
            )
          }
        } header: {
          Text("Profile & Player Info")
        }

        // School Preferences Section
        Section {
          NavigationLink {
            SchoolPreferencesView(preferenceService: preferenceService)
          } label: {
            SettingsRow(
              icon: "target",
              title: "School Preferences",
              description: "Set criteria for finding your ideal schools",
              color: .purple
            )
          }
        } header: {
          Text("School Preferences")
        }

        // Dashboard Section
        Section {
          NavigationLink {
            DashboardCustomizationView(preferenceService: preferenceService)
          } label: {
            SettingsRow(
              icon: "slider.horizontal.3",
              title: "Dashboard Customization",
              description: "Show or hide dashboard widgets",
              color: .blue
            )
          }
        } header: {
          Text("Dashboard")
        }

        // Communication & Social Section
        Section {
          NavigationLink {
            NotificationPreferencesView(preferenceService: preferenceService)
          } label: {
            SettingsRow(
              icon: "bell.fill",
              title: "Notifications",
              description: "Configure alerts for follow-ups, deadlines, and updates",
              color: .orange
            )
          }

          NavigationLink {
            CommunicationTemplatesView()
          } label: {
            SettingsRow(
              icon: "doc.text.fill",
              title: "Communication Templates",
              description: "Create and manage email, text, and social media templates",
              color: .accentBlue
            )
          }
        } header: {
          Text("Communication & Social")
        }

        // Legal Section
        Section {
          Button {
            presentedLegal = .termsOfService
          } label: {
            SettingsRow(
              icon: "doc.text",
              title: "Terms of Service",
              description: "Read the terms and conditions for using the app",
              color: .iconGray
            )
          }
          .buttonStyle(.plain)

          Button {
            presentedLegal = .privacyPolicy
          } label: {
            SettingsRow(
              icon: "hand.raised",
              title: "Privacy Policy",
              description: "How we collect, use, and protect your data",
              color: .iconGray
            )
          }
          .buttonStyle(.plain)
        } header: {
          Text("Legal")
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .task {
        await familyManager.loadFamilyData()
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

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundColor(.white)
        .frame(width: 36, height: 36)
        .background(color)
        .cornerRadius(8)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.body)
          .fontWeight(.medium)
          .foregroundColor(.primary)

        Text(description)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(2)
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(description)")
  }
}

// MARK: - Preview
#if DEBUG
struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
      .environment(AuthManager.shared)
      .environment(FamilyManager.shared)
  }
}
#endif
