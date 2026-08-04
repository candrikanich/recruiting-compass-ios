//
//  HelpSectionDetailView.swift
//  TheRecruitingCompass
//
//  Renders help content for a single section (getting-started, schools, phases, account).
//

import SwiftUI

struct HelpSectionDetailView: View {
  let section: HelpSection

  private let lastReviewed = "February 2026"

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 32) {
        Text("Last reviewed: \(lastReviewed)")
          .font(.caption)
          .foregroundStyle(.secondary)

        HelpSectionContent(section: section)

        HelpFeedbackView(page: "/help/\(section.slug)")
      }
      .padding()
      .padding(.bottom, 24)
    }
    .navigationTitle(section.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct HelpSectionContent: View {
  let section: HelpSection

  var body: some View {
    switch section {
    case .gettingStarted:
      HelpGettingStartedContent()
    case .schools:
      HelpSchoolsContent()
    case .phases:
      HelpPhasesContent()
    case .account:
      HelpAccountContent()
    }
  }
}

// MARK: - Getting Started

private struct HelpGettingStartedContent: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      sectionBlock {
        HelpSectionHeader(title: "What is The Recruiting Compass?")
        Text("The Recruiting Compass is a recruiting management tool built for student athletes and their families. It helps you organize your college search, track schools and coaches, manage the phases of the recruiting process, and stay on top of every interaction along the way.")
          .font(.subheadline)
          .foregroundStyle(.primary)
        HelpCallout(type: .tip, text: "You're in charge of your recruiting journey. The Recruiting Compass keeps everything organized so you can focus on making the right connections.")
      }

      sectionBlock {
        HelpSectionHeader(title: "Creating your profile")
        Text("Your athlete profile is the foundation of everything in the app. Complete it before adding schools or coaches.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HelpStepCard(step: 1, title: "Navigate to Settings", bodyText: "From the dashboard, go to Settings → Athlete Profile.")
        HelpStepCard(step: 2, title: "Fill in your details", bodyText: "Enter your name, graduation year, sport, position(s), GPA, and test scores. All fields help generate accurate fit scores for schools.")
        HelpStepCard(step: 3, title: "Save your profile", bodyText: "Tap Save changes. Your profile is now visible to coaches who view your recruiting page.", isLast: true)
      }

      sectionBlock {
        HelpSectionHeader(title: "Adding family members")
        Text("Parents and guardians can be added as family members to view and collaborate on your recruiting journey.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HelpStepCard(step: 1, title: "Go to Family settings", bodyText: "Navigate to Settings → Family.")
        HelpStepCard(step: 2, title: "Invite a family member", bodyText: "Enter their email address and tap Send invite. They'll receive an email to create their account and join your family unit.", isLast: true)
        HelpCallout(type: .info, text: "Family members can view your school list, phases, and interactions — but only the athlete can make changes to the profile.")
      }

      sectionBlock {
        HelpSectionHeader(title: "Understanding the dashboard")
        Text("The dashboard gives you a snapshot of your recruiting progress at a glance.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HelpImageSlot(caption: "The main dashboard showing your school list, current phase, and recent activity.")
        bulletList(items: [
          ("Current Phase", "where you are in the recruiting process (Freshman through Senior)"),
          ("School list", "your saved schools with fit scores and interaction counts"),
          ("Recent activity", "latest interactions and notifications"),
          ("Tasks", "action items specific to your current phase")
        ])
      }

      sectionBlock {
        HelpSectionHeader(title: "Your first action")
        Text("Once your profile is set up, the most impactful first step is building your school list.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HelpStepCard(step: 1, title: "Search for schools", bodyText: "Go to Search and filter by division, sport, location, or size. Add any school that interests you.", isLast: true)
        HelpCallout(type: .tip, text: "Start broad — you can always narrow your list later. Adding 20–30 schools gives the fit score algorithm enough data to show meaningful patterns.")
      }
    }
  }
}

// MARK: - Schools & Coaches

private struct HelpSchoolsContent: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      sectionBlock {
        HelpSectionHeader(title: "Adding a school to your list")
        Text("Your school list is the core of your recruiting compass. Add every school you're considering, even ones you're unsure about — fit scores will help you prioritize.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HelpStepCard(step: 1, title: "Go to Search", bodyText: "Navigate to Search and use the filters to find schools by division, sport, state, or enrollment size.")
        HelpStepCard(step: 2, title: "View the school profile", bodyText: "Tap any school to see its full profile — academic info, athletic program details, and location.")
        HelpStepCard(step: 3, title: "Add to your list", bodyText: "Tap Add to list. The school now appears on your Schools page with an initial fit score.", isLast: true)
      }

      sectionBlock {
        HelpSectionHeader(title: "What is a fit score?")
        Text("A fit score is a 0–100 rating that reflects how well a school matches your athlete profile. Higher scores indicate a stronger overall fit.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HelpImageSlot(caption: "Fit score breakdown showing academic, athletic, and location dimensions.")
        Text("Fit scores are calculated from four dimensions:")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        bulletList(items: [
          ("Academic fit", "your GPA and test scores vs. the school's average admit profile"),
          ("Athletic fit", "your sport and level vs. the school's program division and roster needs"),
          ("Size fit", "enrollment size preference match"),
          ("Location fit", "proximity to home and region preference")
        ])
        HelpCallout(type: .info, text: "Fit scores update automatically when you update your athlete profile. Keep your profile current for the most accurate scores.")
      }

      sectionBlock {
        HelpSectionHeader(title: "Managing your school list", badge: .required)
        Text("Your school list drives everything else in the app — phases, interactions, and recommendation letters are all tied to specific schools.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        bulletList(items: [
          ("Sort", "by fit score, recent activity, or date added"),
          ("Filter", "by division, state, or interaction status"),
          ("Remove", "tap the school and select Remove from list. This also removes associated interactions.")
        ])
        HelpCallout(type: .warning, text: "Removing a school permanently deletes all coach interactions and notes tied to that school. Archive instead of removing if you want to keep the history.")
      }

      sectionBlock {
        HelpSectionHeader(title: "Logging a coach interaction")
        Text("Every time you communicate with a coach — email, call, campus visit — log it as an interaction. This creates a timeline of your recruiting relationship with each school.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HelpStepCard(step: 1, title: "Open a school", bodyText: "Go to your Schools page and tap the school you interacted with.")
        HelpStepCard(step: 2, title: "Select a coach", bodyText: "Tap a coach on the school's page, or tap Add coach if they're not listed yet.")
        HelpStepCard(step: 3, title: "Log the interaction", bodyText: "Tap Log interaction, choose the type, set the date, and add any notes. Tap Save.", isLast: true)
      }

      sectionBlock {
        HelpSectionHeader(title: "Interaction types")
        Text("Choose the type that best describes how contact was made.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        interactionTypeRow(icon: "envelope", title: "Email", detail: "written correspondence with a coach")
        interactionTypeRow(icon: "phone", title: "Phone call", detail: "direct conversation by phone")
        interactionTypeRow(icon: "building.2", title: "Campus visit", detail: "official or unofficial campus visit")
        interactionTypeRow(icon: "bubble.left", title: "Social media", detail: "DMs, follows, or replies on social platforms")
        interactionTypeRow(icon: "doc", title: "Other", detail: "anything that doesn't fit the above")
        HelpCallout(type: .tip, text: "Log interactions on the same day they happen. Notes are easier to write while the details are fresh.")
      }
    }
  }
}

// MARK: - Phases & Letters

private struct HelpPhasesContent: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      sectionBlock {
        HelpSectionHeader(title: "Overview of recruiting phases")
        Text("The recruiting process is organized into four phases that map to your high school career. Each phase unlocks specific features and actions in the app.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HelpImageSlot(caption: "The four recruiting phases: Freshman, Sophomore, Junior, and Senior.")
      }

      sectionBlock {
        HelpSectionHeader(title: "What each phase means")
        phaseCard(title: "Freshman", badge: .optional, text: "The awareness phase. Focus on building your athlete profile, exploring what divisions and programs exist, and adding initial schools to your list. NCAA contact rules are restrictive at this stage — coaches generally can't reach out to you yet.")
        phaseCard(title: "Sophomore", badge: nil, text: "The research phase. Refine your school list, attend camps and showcases to get exposure, and begin logging early interactions. Start identifying target coaches at schools you're serious about.")
        phaseCard(title: "Junior", badge: .required, text: "The active phase. This is when most serious recruiting communication happens. Coaches can now initiate contact. Log every interaction, request recommendation letters, and begin scheduling official campus visits. NCAA signing periods begin in your junior year for some sports.")
        phaseCard(title: "Senior", badge: .required, text: "The decision phase. Narrow your list to schools that have extended offers or strong interest. Finalize rec letters, make official visits, and track deadlines. National Signing Day typically falls in your senior year.")
      }

      sectionBlock {
        HelpSectionHeader(title: "How to advance your phase")
        Text("Phase advancement is a confirmed action — both you and a coach or family member must confirm the transition.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HelpStepCard(step: 1, title: "Open Phase settings", bodyText: "Go to Settings → Recruiting Phase.")
        HelpStepCard(step: 2, title: "Request advancement", bodyText: "Tap Advance to [next phase]. A confirmation request is sent to your family unit.")
        HelpStepCard(step: 3, title: "Family confirms", bodyText: "A family member confirms the advancement in their notification feed. Once confirmed, your phase updates and new features unlock.", isLast: true)
        HelpCallout(type: .warning, text: "Phase advancement cannot be reversed. Make sure you're ready before requesting the change.")
      }

      sectionBlock {
        HelpSectionHeader(title: "Requesting a recommendation letter")
        Text("Recommendation letters from coaches, teachers, or counselors strengthen your recruiting profile. Track all your requests in one place.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HelpStepCard(step: 1, title: "Go to Documents", bodyText: "Navigate to Documents and select the Recommendation Letters tab.")
        HelpStepCard(step: 2, title: "Add a new request", bodyText: "Tap Request letter and enter the recommender's name, relationship, and the school or program the letter is for.")
        HelpStepCard(step: 3, title: "Set a deadline", bodyText: "Add the submission deadline so you receive a reminder before it's due.", isLast: true)
        HelpCallout(type: .tip, text: "Ask for recommendation letters at least 4–6 weeks before the deadline. Give your recommenders plenty of context about the school and what makes you a strong candidate.")
      }

      sectionBlock {
        HelpSectionHeader(title: "Tracking letter status")
        Text("Each letter request moves through these states:")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        letterStatusRow(label: "Requested", color: .orange, text: "You've submitted the request. Waiting for the recommender to confirm.")
        letterStatusRow(label: "In progress", color: .blue, text: "The recommender has confirmed they'll write it.")
        letterStatusRow(label: "Received", color: .green, text: "The letter has been submitted to the school or delivered to you.")
      }
    }
  }
}

// MARK: - Account & Settings

private struct HelpAccountContent: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      sectionBlock {
        HelpSectionHeader(title: "Updating your athlete profile")
        Text("Keep your profile current — fit scores and recommendations update automatically when your profile changes.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HelpStepCard(step: 1, title: "Open Settings", bodyText: "Navigate to Settings and select Athlete Profile.")
        HelpStepCard(step: 2, title: "Edit your details", bodyText: "Update any field — graduation year, sport, positions, GPA, SAT/ACT, height, or weight.")
        HelpStepCard(step: 3, title: "Save changes", bodyText: "Tap Save changes. Fit scores for all your schools will recalculate within a few seconds.", isLast: true)
      }

      sectionBlock {
        HelpSectionHeader(title: "Managing family members")
        Text("Family members (parents, guardians) can view your recruiting profile and help confirm phase advancements.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HelpStepCard(step: 1, title: "Go to Family settings", bodyText: "Navigate to Settings → Family.")
        HelpStepCard(step: 2, title: "Invite a member", bodyText: "Enter their email and tap Send invite. They'll receive an invitation to create a linked account.")
        HelpStepCard(step: 3, title: "Manage access", bodyText: "To remove a family member, tap the three-dot menu next to their name and select Remove.", isLast: true)
        HelpCallout(type: .info, text: "A family member's account is linked to your athlete profile — they cannot log in as you or make changes on your behalf.")
      }

      sectionBlock {
        HelpSectionHeader(title: "Notification preferences")
        Text("Control which notifications you receive and how you receive them.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Text("Go to Settings → Notifications to enable or disable notifications by category.")
          .font(.subheadline)
          .foregroundStyle(.primary)
        HelpCallout(type: .tip, text: "Keep Phase confirmations and Rec letter updates notifications enabled — these are time-sensitive actions that require your attention.")
      }

      sectionBlock {
        HelpSectionHeader(title: "Understanding notification types")
        VStack(alignment: .leading, spacing: 12) {
          notificationPriorityRow(title: "High priority", items: [
            "Phase advancement confirmation requests",
            "Recommendation letter deadline reminders (7 days out)",
            "New family member invitation"
          ])
          notificationPriorityRow(title: "Medium priority", items: [
            "Interaction logged by a family member",
            "Recommendation letter status change",
            "Phase advancement completed"
          ])
          notificationPriorityRow(title: "Low priority", items: [
            "Weekly recruiting activity summary",
            "School list milestone (e.g., 10 schools added)"
          ])
        }
      }

      sectionBlock {
        HelpSectionHeader(title: "Changing your password")
        HelpStepCard(step: 1, title: "Go to Account settings", bodyText: "Navigate to Settings → Account.")
        HelpStepCard(step: 2, title: "Tap Change password", bodyText: "Enter your current password, then your new password twice to confirm.")
        HelpStepCard(step: 3, title: "Save", bodyText: "Tap Update password. You'll be asked to log in again with your new credentials.", isLast: true)
      }

      sectionBlock {
        HelpSectionHeader(title: "Data and privacy")
        Text("Your data is stored securely and never shared with third parties or college programs without your consent. The Recruiting Compass does not sell user data.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        bulletList(items: [
          ("What we store", "your athlete profile, school list, coach interactions, and app activity"),
          ("Who can see it", "only you and family members you've invited"),
          ("To delete your account", "go to Settings → Account → Delete account. This permanently removes all your data.")
        ])
        HelpCallout(type: .important, text: "Account deletion is permanent and cannot be undone. Export your data before deleting if you want to keep a record of your recruiting history.")
      }
    }
  }
}

// MARK: - Shared content helpers

@ViewBuilder
private func sectionBlock<Content: View>(@ViewBuilder content: () -> Content) -> some View {
  VStack(alignment: .leading, spacing: 12) {
    content()
  }
  .frame(maxWidth: .infinity, alignment: .leading)
}

private func bulletList(items: [(String, String)]) -> some View {
  VStack(alignment: .leading, spacing: 8) {
    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
      HStack(alignment: .top, spacing: 8) {
        Text("•")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Text("\(item.0) — \(item.1)")
          .font(.subheadline)
          .foregroundStyle(.primary)
      }
    }
  }
}

private func interactionTypeRow(icon: String, title: String, detail: String) -> some View {
  HStack(alignment: .top, spacing: 12) {
    Image(systemName: icon)
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .frame(width: 20, alignment: .center)
    Text("\(title) — \(detail)")
      .font(.subheadline)
      .foregroundStyle(.primary)
  }
}

private func phaseCard(title: String, badge: HelpBadge.BadgeType?, text: String) -> some View {
  VStack(alignment: .leading, spacing: 8) {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(title)
        .font(.headline)
        .foregroundStyle(.primary)
      if let badge {
        HelpBadge(type: badge)
      }
    }
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
  }
  .padding(16)
  .frame(maxWidth: .infinity, alignment: .leading)
  .background(Color(.secondarySystemBackground))
  .clipShape(RoundedRectangle(cornerRadius: 12))
}

private func letterStatusRow(label: String, color: Color, text: String) -> some View {
  HStack(alignment: .top, spacing: 12) {
    Text(label)
      .font(.caption)
      .fontWeight(.medium)
      .foregroundStyle(color)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(color.opacity(0.2))
      .clipShape(Capsule())
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
  }
}

private func notificationPriorityRow(title: String, items: [String]) -> some View {
  VStack(alignment: .leading, spacing: 4) {
    Text(title)
      .font(.subheadline)
      .fontWeight(.semibold)
      .foregroundStyle(.primary)
    ForEach(items, id: \.self) { item in
      Text("• \(item)")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }
}

#Preview("Getting Started") {
  NavigationStack {
    HelpSectionDetailView(section: .gettingStarted)
  }
}

#Preview("Schools") {
  NavigationStack {
    HelpSectionDetailView(section: .schools)
  }
}
