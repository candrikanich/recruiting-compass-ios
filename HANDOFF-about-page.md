# iOS Handoff: About & Feedback Feature

**Source of truth:** Web implementation in `recruiting-compass-web`
**Branch:** `develop`
**Date:** 2026-03-08

---

## What Was Built on Web

An authenticated About page with two purposes:

1. **Mission statement** — a short paragraph about The Recruiting Compass
2. **Feedback form** — structured contact form that emails submissions to `info@therecruitingcompass.com`

The web page lives at `/about` and is linked from the bottom of the Settings page under an "App" section.

---

## What to Build on iOS

Mirror the web feature:

1. **`FeedbackService`** — new service that calls `POST /api/feedback` on the web backend
2. **`AboutView`** — new SwiftUI view with mission statement + feedback form
3. **Update `SettingsView`** — add an "App" section at the bottom linking to `AboutView`

> ⚠️ Do NOT modify `HelpFeedbackService` or `HelpFeedbackView`. Those are thumbs up/down feedback for the Help Center and go to a Supabase table. This is a separate feature.

---

## API Endpoint

**`POST /api/feedback`**

- **Base URL:** `SupabaseConfig.apiBaseURL` (already in codebase — resolves to `https://myrecruitingcompass.com` in production)
- **Auth:** `Authorization: Bearer <token>` — get token via `supabaseManager.client.auth.session.accessToken`
- **Content-Type:** `application/json`

**Request body:**
```json
{
  "subject": "bug" | "feature" | "question" | "general",
  "message": "string (1–5000 chars)"
}
```

**Success response:**
```json
{ "success": true }
```

**Error responses:**
- `400` — validation failure (invalid subject, empty/oversized message)
- `401` — unauthenticated
- `500` — email send failure

### Established API Call Pattern

Follow `FamilyServiceImpl.createFamilyViaAPI()` exactly:

```swift
let url = baseURL.appendingPathComponent("api/feedback")
let token = try await supabaseManager.client.auth.session.accessToken
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = try JSONEncoder().encode(body)
let (data, response) = try await URLSession.shared.data(for: request)
guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
    throw FeedbackError.serverError
}
```

---

## Files to Create

### 1. `Features/About/Services/FeedbackService.swift`

```swift
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FeedbackService")

enum FeedbackSubject: String, CaseIterable {
    case bug = "bug"
    case feature = "feature"
    case question = "question"
    case general = "general"

    var displayName: String {
        switch self {
        case .bug: return "Bug Report"
        case .feature: return "Feature Request"
        case .question: return "Question"
        case .general: return "General Feedback"
        }
    }
}

enum FeedbackError: LocalizedError {
    case notConfigured
    case serverError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Feedback service is not available."
        case .serverError: return "Failed to send feedback. Please try again."
        case .networkError: return "Network error. Please check your connection."
        }
    }
}

protocol FeedbackManaging: Sendable {
    func submit(subject: FeedbackSubject, message: String) async throws
}

final class FeedbackServiceImpl: FeedbackManaging, Sendable {
    private let supabaseManager: SupabaseManager

    init(supabaseManager: SupabaseManager = .shared) {
        self.supabaseManager = supabaseManager
    }

    func submit(subject: FeedbackSubject, message: String) async throws {
        guard let baseURL = SupabaseConfig.apiBaseURL else {
            logger.error("apiBaseURL not configured")
            throw FeedbackError.notConfigured
        }

        let url = baseURL.appendingPathComponent("api/feedback")
        let token = try await supabaseManager.client.auth.session.accessToken

        struct Body: Encodable {
            let subject: String
            let message: String
        }

        let body = Body(subject: subject.rawValue, message: message)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        logger.debug("Submitting feedback: subject=\(subject.rawValue)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            logger.error("Feedback network error: \(error.localizedDescription)")
            throw FeedbackError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "(unreadable)"
            logger.error("Feedback failed: body=\(body, privacy: .private)")
            throw FeedbackError.serverError
        }

        logger.info("Feedback submitted successfully: subject=\(subject.rawValue)")
    }
}
```

---

### 2. `Features/About/ViewModels/AboutViewModel.swift`

```swift
import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "AboutViewModel")

@Observable
@MainActor
final class AboutViewModel {
    var selectedSubject: FeedbackSubject = .general
    var message: String = ""
    var isLoading: Bool = false
    var submissionState: SubmissionState = .idle

    enum SubmissionState {
        case idle
        case success
        case failure(String)
    }

    private let feedbackService: FeedbackManaging

    init(feedbackService: FeedbackManaging = FeedbackServiceImpl()) {
        self.feedbackService = feedbackService
    }

    var isFormValid: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var characterCount: Int {
        message.count
    }

    func submit() async {
        guard isFormValid, !isLoading else { return }
        isLoading = true
        submissionState = .idle

        do {
            try await feedbackService.submit(subject: selectedSubject, message: message)
            submissionState = .success
            message = ""
            selectedSubject = .general
            // Auto-reset after 5 seconds (matches web behaviour)
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            submissionState = .idle
        } catch {
            logger.error("Feedback submission failed: \(error.localizedDescription)")
            submissionState = .failure(error.localizedDescription)
        }

        isLoading = false
    }
}
```

---

### 3. `Features/About/Views/AboutView.swift`

```swift
import SwiftUI

struct AboutView: View {
    @State private var viewModel = AboutViewModel()

    var body: some View {
        List {
            // Mission statement
            Section {
                Text(
                    "The Recruiting Compass helps high school student athletes and their families manage the college recruiting journey — tracking schools, coaches, interactions, and timelines in one place. We believe every athlete deserves clarity, control, and a fair shot. No professional service required."
                )
                .font(.body)
                .foregroundColor(.primary)
                .padding(.vertical, 4)
            }

            // Feedback form
            Section {
                // Subject picker
                Picker("Subject", selection: $viewModel.selectedSubject) {
                    ForEach(FeedbackSubject.allCases, id: \.self) { subject in
                        Text(subject.displayName).tag(subject)
                    }
                }
                .accessibilityLabel("Feedback subject")

                // Message field
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

                // Status messages
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

                // Submit button
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

            // Fallback contact
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
```

---

## Files to Modify

### `Features/Settings/Views/SettingsView.swift`

Add a new `Section` at the bottom of the `List`, **after the Legal section and before the closing `}`**:

```swift
// App Section
Section {
    NavigationLink {
        AboutView()
    } label: {
        SettingsRow(
            icon: "info.circle.fill",
            title: "About & Feedback",
            description: "Our mission, and a way to send us feedback or report issues",
            color: .iconGray
        )
    }
} header: {
    Text("App")
}
```

---

## Validation Rules (match server exactly)

| Field | Rule |
|---|---|
| subject | One of: `bug`, `feature`, `question`, `general` |
| message | Non-empty, max 5000 characters |

The client should enforce max 5000 characters via the character counter. The server enforces both rules and returns 400 on failure.

---

## Error Handling

| Scenario | UX |
|---|---|
| `apiBaseURL` not configured | Show error banner: "Feedback service is not available." |
| Network failure | Show error banner: "Network error. Please check your connection." |
| Server error (4xx/5xx) | Show error banner: "Failed to send feedback. Please try again." |
| Success | Show green success banner, clear form, auto-reset after 5 seconds |

---

## Testing Checklist

- [ ] `FeedbackService` unit tests using a mock `URLSession` or protocol-based mock
  - Valid submission → success
  - `apiBaseURL` nil → throws `FeedbackError.notConfigured`
  - Non-2xx response → throws `FeedbackError.serverError`
  - Network error → throws `FeedbackError.networkError`
- [ ] `AboutViewModel` unit tests with a mock `FeedbackManaging`
  - `isFormValid` is false when message is empty
  - `submit()` sets `submissionState = .success` on success
  - `submit()` sets `submissionState = .failure` on error
  - `submit()` is a no-op if `isLoading` is true
- [ ] Manual: navigate Settings → About & Feedback, submit with each subject category, confirm email arrives at `info@therecruitingcompass.com`

---

## Notes

- `SupabaseConfig.apiBaseURL` is `nil` when `API_BASE_URL` env var is not set in the debug scheme — handle gracefully (show error, don't crash)
- `FeedbackSubject.allCases` works because `FeedbackSubject` conforms to `CaseIterable`
- `primaryGreen` and `errorRed` and `iconGray` are existing Color extensions in the project
- Do not modify `HelpFeedbackService` or `HelpFeedbackView` — they are unrelated
