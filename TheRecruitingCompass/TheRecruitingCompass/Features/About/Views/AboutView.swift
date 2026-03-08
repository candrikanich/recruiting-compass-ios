import SwiftUI

struct AboutView: View {
    @State private var viewModel = AboutViewModel()

    var body: some View {
        List {
            Section {
                // swiftlint:disable:next line_length
                Text("The Recruiting Compass helps high school student athletes and their families manage the college recruiting journey — tracking schools, coaches, interactions, and timelines in one place. We believe every athlete deserves clarity, control, and a fair shot. No professional service required.")
                .font(.body)
                .foregroundColor(.primary)
                .padding(.vertical, 4)
            }

            Section {
                Picker("Subject", selection: $viewModel.selectedSubject) {
                    ForEach(FeedbackSubject.allCases, id: \.self) { subject in
                        Text(subject.displayName).tag(subject)
                    }
                }
                .accessibilityLabel("Feedback subject")

                VStack(alignment: .leading, spacing: 4) {
                    TextField(
                        "Tell us what's on your mind...",
                        text: $viewModel.message,
                        axis: .vertical
                    )
                    .lineLimit(6...12)
                    .accessibilityLabel("Message")
                    .accessibilityHint("Enter your feedback message")

                    Text("\(viewModel.characterCount) / 5000")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                switch viewModel.submissionState {
                case .success:
                    Label("Thanks for your message — we'll be in touch soon.", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.primaryGreen)
                        .accessibilityLabel("Message sent successfully")

                case .failure(let message):
                    Label(message, systemImage: "exclamationmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.errorRed)
                        .accessibilityLabel("Error: \(message)")

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
                .accessibilityLabel(viewModel.isLoading ? "Sending message" : "Send message")
                .accessibilityHint(viewModel.isFormValid ? "Submit your feedback" : "Enter a message before sending")

            } header: {
                Text("Send Us a Message")
            }

            Section {
                Link(destination: URL(string: "mailto:info@therecruitingcompass.com")!) {
                    Label("info@therecruitingcompass.com", systemImage: "envelope")
                        .font(.subheadline)
                }
                .accessibilityLabel("Email us at info@therecruitingcompass.com")
            } header: {
                Text("Direct Contact")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
