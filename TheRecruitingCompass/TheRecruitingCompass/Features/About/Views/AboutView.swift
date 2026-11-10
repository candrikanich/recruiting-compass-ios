import SwiftUI

struct AboutView: View {
    @State private var viewModel = AboutViewModel()

    var body: some View {
        List {
            Section {
                // swiftlint:disable:next line_length
                Text("The Recruiting Compass helps high school student athletes and their families manage the college recruiting journey — tracking schools, coaches, interactions, and timelines in one place. We believe every athlete deserves clarity, control, and a fair shot. No professional service required.")
                .font(.brand(.body))
                .foregroundStyle(.primary)
                .padding(.vertical, 4)
            }

            Section {
                Picker("Subject", selection: $viewModel.selectedSubject) {
                    ForEach(FeedbackSubject.allCases, id: \.self) { subject in
                        Text(subject.displayName).tag(subject)
                    }
                }
                .accessibilityLabel(String(localized: "Feedback subject"))

                VStack(alignment: .leading, spacing: 4) {
                    TextField(
                        "Tell us what's on your mind...",
                        text: $viewModel.message,
                        axis: .vertical
                    )
                    .lineLimit(6...12)
                    .accessibilityLabel(String(localized: "Message"))
                    .accessibilityHint("Enter your feedback message")

                    Text("\(viewModel.characterCount) / 5000")
                        .font(.brand(.caption))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                switch viewModel.submissionState {
                case .success:
                    Label("Thanks for your message — we'll be in touch soon.", systemImage: "checkmark.circle.fill")
                        .font(.brand(.subheadline))
                        .foregroundStyle(Color.primaryGreen)
                        .accessibilityLabel(String(localized: "Message sent successfully"))

                case .failure(let message):
                    Label(message, systemImage: "exclamationmark.circle.fill")
                        .font(.brand(.subheadline))
                        .foregroundStyle(Color.errorRed)
                        .accessibilityLabel(String(localized: "Error: \(message)"))

                case .idle:
                    EmptyView()
                }

                Button {
                    Task { await viewModel.submit() }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 4)
                        }
                        Text("Send Message")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.isLoading || !viewModel.isFormValid)
                .accessibilityLabel(viewModel.isLoading ? String(localized: "Sending message") : String(localized: "Send message"))
                .accessibilityHint(viewModel.isFormValid ? "Submit your feedback" : "Enter a message before sending")

            } header: {
                Text("Send Us a Message")
            }

            Section {
                Link(destination: URL(string: "mailto:hello@therecruitingcompass.com")!) {
                    Label("hello@therecruitingcompass.com", systemImage: "envelope")
                        .font(.brand(.subheadline))
                }
                .accessibilityLabel(String(localized: "Email us at hello@therecruitingcompass.com"))
            } header: {
                Text("Direct Contact")
            }

            dataSourcesSection

            Section {
                LabeledContent("Version", value: AppInfo.displayVersion)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("aboutAppVersion")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Wikipedia's CC BY-SA 4.0 license requires credit, a license link and a notice that the data was
    /// adapted — row 1 must keep all three. Copy and URLs match web `pages/about.vue`. Each row is a
    /// string literal so it stays a `LocalizedStringKey` and its Markdown links render.
    @ViewBuilder
    private var dataSourcesSection: some View {
        Section {
            Group {
                // swiftlint:disable:next line_length
                Text("School nicknames and team colors are adapted from [Wikipedia](https://en.wikipedia.org/wiki/Module:College_color/data), available under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Some Division I colors come from [ncaa-team-colors](https://github.com/glidej/ncaa-team-colors).")
                Text("College search data comes from the U.S. Department of Education's [College Scorecard](https://collegescorecard.ed.gov/).")
                Text("School logos are provided by [Logo.dev](https://logo.dev).")
            }
            .font(.brand(.subheadline))
            .foregroundStyle(.secondary)
            .tint(Color.primaryGreen)
            .accessibilityIdentifier("aboutDataSources")
        } header: {
            Text("Data Sources")
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
