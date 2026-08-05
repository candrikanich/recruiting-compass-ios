import SwiftUI
import PhotosUI

private enum ProfileDestination: Hashable {
    case playerDetails
}

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = ProfileViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?

    private let preferenceService: any PreferenceManaging

    init(preferenceService: any PreferenceManaging = PreferenceServiceImpl(supabaseManager: .shared)) {
        self.preferenceService = preferenceService
    }

    private var user: User? { authManager.user }
    private var isAthlete: Bool { user?.role == .player }

    var body: some View {
        List {
            ProfilePhotoSection(viewModel: viewModel, user: user, selectedPhotoItem: $selectedPhotoItem)
            ProfilePersonalInfoSection(viewModel: viewModel, isAthlete: isAthlete)
            ProfileEmailSection(viewModel: viewModel, email: user?.email)
            ProfilePasswordSection(viewModel: viewModel)
            if isAthlete {
                ProfileAthleteSection()
            }
            ProfileDataPrivacySection(viewModel: viewModel)
        }
        .navigationTitle("My Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ProfileDestination.self) { destination in
            switch destination {
            case .playerDetails:
                PlayerDetailsView(preferenceService: preferenceService, userRole: .player)
            }
        }
        .task {
            viewModel.loadInitialState()
            await viewModel.loadDeletionStatus()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        viewModel.photoError = "Failed to load the selected photo. Please try again."
                        selectedPhotoItem = nil
                        return
                    }
                    // Decode off the main actor: UIImage(data:) on a full-resolution
                    // photo can be expensive enough to visibly stall the UI.
                    guard let image = await Task.detached(priority: .userInitiated, operation: {
                        UIImage(data: data)
                    }).value else {
                        viewModel.photoError = "Failed to load the selected photo. Please try again."
                        selectedPhotoItem = nil
                        return
                    }
                    await viewModel.uploadPhoto(image)
                } catch {
                    viewModel.photoError = "Failed to load the selected photo. Please try again."
                }
                selectedPhotoItem = nil
            }
        }
        .alert("Remove Profile Photo", isPresented: $viewModel.showRemovePhotoConfirm) {
            Button("Remove", role: .destructive) {
                Task { await viewModel.removePhoto() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove your profile photo? You can upload a new one anytime.")
        }
    }
}

// MARK: - Section 1: Profile Photo

private struct ProfilePhotoSection: View {
    @Bindable var viewModel: ProfileViewModel
    let user: User?
    @Binding var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        Section {
            HStack(spacing: 16) {
                ProfilePhotoAvatar(user: user)
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 8) {
                    if viewModel.isUploadingPhoto {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .frame(maxWidth: .infinity)
                    } else {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Text("Upload Photo")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(String(localized: "Upload profile photo"))

                        if user?.profilePhotoUrl != nil {
                            Button("Remove", role: .destructive) {
                                viewModel.showRemovePhotoConfirm = true
                            }
                            .font(.subheadline)
                            .accessibilityLabel(String(localized: "Remove profile photo"))
                        }
                    }

                    if let error = viewModel.photoError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.errorRed)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
        }
    }
}

private struct ProfilePhotoAvatar: View {
    let user: User?

    var body: some View {
        if let urlString = user?.profilePhotoUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    InitialsAvatar(initials: userInitials(from: user?.fullName))
                }
            }
        } else {
            InitialsAvatar(initials: userInitials(from: user?.fullName))
        }
    }
}

// MARK: - Section 2: Personal Information

private struct ProfilePersonalInfoSection: View {
    @Bindable var viewModel: ProfileViewModel
    let isAthlete: Bool

    var body: some View {
        Section {
            TextField("Full Name", text: $viewModel.fullName)
                .accessibilityLabel(String(localized: "Full name"))

            TextField("Phone (optional)", text: $viewModel.phone)
                .keyboardType(.phonePad)
                .accessibilityLabel(String(localized: "Phone number"))

            if isAthlete {
                DateOfBirthField(value: $viewModel.dateOfBirth)
            }

            if let msg = viewModel.personalInfoMessage {
                Label(msg.text, systemImage: msg.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(msg.isSuccess ? Color.primaryGreen : Color.errorRed)
                    .accessibilityLabel(msg.isSuccess ? "Saved successfully" : String(localized: "Error: \(msg.text)"))
            }

            Button {
                Task { await viewModel.savePersonalInfo() }
            } label: {
                HStack {
                    if viewModel.isSavingPersonalInfo {
                        ProgressView().scaleEffect(0.8).padding(.trailing, 4)
                    }
                    Text("Save")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(viewModel.isSavingPersonalInfo || !viewModel.isPersonalInfoValid)
            .accessibilityLabel(viewModel.isSavingPersonalInfo ? String(localized: "Saving") : String(localized: "Save personal information"))

        } header: {
            Text("Personal Information")
        }
    }
}

// MARK: - Section 3: Email

private struct ProfileEmailSection: View {
    @Bindable var viewModel: ProfileViewModel
    let email: String?

    var body: some View {
        Section {
            if let email {
                HStack {
                    Text("Current:")
                        .foregroundStyle(.secondary)
                    Text(email)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Current email: \(email)")
            }

            if viewModel.emailVerificationBannerVisible {
                Label(
                    "A verification email has been sent to your new address. Check your inbox to confirm the change.",
                    systemImage: "envelope.badge"
                )
                .font(.subheadline)
                .foregroundStyle(.blue)
                .accessibilityLabel(String(localized: "Verification email sent. Check your inbox."))
            }

            if viewModel.isEmailFormExpanded {
                TextField("New Email Address", text: $viewModel.newEmail)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel(String(localized: "New email address"))

                SecureField("Current Password", text: $viewModel.emailCurrentPassword)
                    .textContentType(.password)
                    .accessibilityLabel(String(localized: "Current password to confirm email change"))

                if let msg = viewModel.emailMessage {
                    Text(msg.text)
                        .font(.subheadline)
                        .foregroundStyle(Color.errorRed)
                        .accessibilityLabel("Error: \(msg.text)")
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await viewModel.submitEmailChange() }
                    } label: {
                        HStack {
                            if viewModel.isSavingEmail {
                                ProgressView().scaleEffect(0.8).padding(.trailing, 4)
                            }
                            Text("Update Email").fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSavingEmail)
                    .accessibilityLabel(viewModel.isSavingEmail ? String(localized: "Updating email") : String(localized: "Update email"))

                    Button("Cancel") {
                        viewModel.isEmailFormExpanded = false
                        viewModel.newEmail = ""
                        viewModel.emailCurrentPassword = ""
                        viewModel.emailMessage = nil
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(String(localized: "Cancel email change"))
                }
            } else {
                Button("Change Email") {
                    viewModel.isEmailFormExpanded = true
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(String(localized: "Change email address"))
            }
        } header: {
            Text("Email Address")
        }
    }
}

// MARK: - Section 4: Password

private struct ProfilePasswordSection: View {
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        Section {
            SecureField("Current Password", text: $viewModel.currentPassword)
                .textContentType(.password)
                .accessibilityLabel(String(localized: "Current password"))

            SecureField("New Password (min 8 characters)", text: $viewModel.newPassword)
                .textContentType(.newPassword)
                .accessibilityLabel(String(localized: "New password, minimum 8 characters"))

            SecureField("Confirm New Password", text: $viewModel.confirmPassword)
                .textContentType(.newPassword)
                .accessibilityLabel(String(localized: "Confirm new password"))

            if !viewModel.confirmPassword.isEmpty && !viewModel.passwordsMatch {
                Text("Passwords do not match.")
                    .font(.subheadline)
                    .foregroundStyle(Color.errorRed)
                    .accessibilityLabel(String(localized: "Error: Passwords do not match"))
            }

            if let msg = viewModel.passwordMessage {
                Label(msg.text, systemImage: msg.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(msg.isSuccess ? Color.primaryGreen : Color.errorRed)
                    .accessibilityLabel(msg.isSuccess ? msg.text : String(localized: "Error: \(msg.text)"))
            }

            Button {
                Task { await viewModel.savePassword() }
            } label: {
                HStack {
                    if viewModel.isSavingPassword {
                        ProgressView().scaleEffect(0.8).padding(.trailing, 4)
                    }
                    Text("Update Password")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(viewModel.isSavingPassword || !viewModel.isPasswordFormValid)
            .accessibilityLabel(viewModel.isSavingPassword ? String(localized: "Updating password") : String(localized: "Update password"))

        } header: {
            Text("Password")
        }
    }
}

// MARK: - Section 5: Athlete Profile (athletes only)

private struct ProfileAthleteSection: View {
    var body: some View {
        Section {
            NavigationLink(value: ProfileDestination.playerDetails) {
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.green)
                        .clipShape(.rect(cornerRadius: 8))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Athlete Profile")
                            .font(.body.weight(.medium))
                        Text("Manage your recruiting profile — positions, stats, academic scores, and social handles.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 4)
            }
            .accessibilityLabel(String(localized: "Athlete Profile: Manage your recruiting profile"))
        } header: {
            Text("Athlete Profile")
        }
    }
}

// MARK: - Section 6: Data & Privacy

private struct ProfileDataPrivacySection: View {
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        Section {
            switch viewModel.deletionState {
            case .noRequest:
                ProfileDeletionDefaultState(viewModel: viewModel)

            case .confirmStep:
                ProfileDeletionConfirmState(viewModel: viewModel)

            case .pending(let scheduledFor):
                ProfileDeletionPendingState(viewModel: viewModel, scheduledFor: scheduledFor)
            }

            if let error = viewModel.deletionError {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(Color.errorRed)
                    .accessibilityLabel("Error: \(error)")
            }
        } header: {
            Text("Data & Privacy")
        }
    }
}

private struct ProfileDeletionDefaultState: View {
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // swiftlint:disable:next line_length
            Text("You can request deletion of your account and all associated data. Your account will be permanently deleted 30 days after your request, giving you time to change your mind.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                viewModel.beginDeletionRequest()
            } label: {
                Text("Request Account Deletion")
                    .fontWeight(.medium)
                    .foregroundStyle(Color.errorRed)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.errorRed)
            .accessibilityLabel(String(localized: "Request account deletion"))
        }
        .padding(.vertical, 4)
    }
}

private struct ProfileDeletionConfirmState: View {
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("This action cannot be easily undone.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.errorRed)

                VStack(alignment: .leading, spacing: 4) {
                    bulletItem("All your schools, coaches, interactions, and notes will be deleted")
                    bulletItem("You will be removed from any shared family units")
                    bulletItem("Your account will be permanently deleted after 30 days")
                    bulletItem("You may cancel within the 30-day window")
                }
            }
            .padding(12)
            .background(Color.errorRed.opacity(0.08))
            .clipShape(.rect(cornerRadius: 8))

            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.confirmDeletion() }
                } label: {
                    HStack {
                        if viewModel.isLoadingDeletion {
                            ProgressView().scaleEffect(0.8).tint(.white).padding(.trailing, 4)
                        }
                        Text("Yes, delete my account").fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.errorRed)
                .disabled(viewModel.isLoadingDeletion)
                .accessibilityLabel(String(localized: "Confirm account deletion"))

                Button("Cancel") {
                    viewModel.cancelDeletionConfirm()
                }
                .foregroundStyle(.secondary)
                .accessibilityLabel(String(localized: "Cancel account deletion"))
            }
        }
        .padding(.vertical, 4)
    }

    private func bulletItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundStyle(Color.errorRed)
            Text(text).font(.caption).foregroundStyle(.primary)
        }
    }
}

private struct ProfileDeletionPendingState: View {
    @Bindable var viewModel: ProfileViewModel
    let scheduledFor: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your account is scheduled for deletion on \(scheduledFor.formatted(date: .long, time: .omitted)).")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
                Text("All your data will be permanently removed on that date. You can cancel this request before then.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .clipShape(.rect(cornerRadius: 8))

            Button {
                Task { await viewModel.cancelDeletionRequest() }
            } label: {
                HStack {
                    if viewModel.isLoadingDeletion {
                        ProgressView().scaleEffect(0.8).padding(.trailing, 4)
                    }
                    Text("Cancel Deletion Request")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoadingDeletion)
            .accessibilityLabel(String(localized: "Cancel account deletion request"))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Date of Birth Field

private struct DateOfBirthField: View {
    @Binding var value: String

    private static let dobFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var date: Binding<Date> {
        Binding(
            get: { Self.dobFormatter.date(from: value) ?? .now },
            set: { value = Self.dobFormatter.string(from: $0) }
        )
    }

    var body: some View {
        DatePicker(
            "Date of Birth",
            selection: date,
            in: ...Date.now,
            displayedComponents: .date
        )
        .accessibilityLabel(String(localized: "Date of birth"))
    }
}

// MARK: - Helpers

private func userInitials(from fullName: String?) -> String {
    guard let name = fullName, !name.isEmpty else { return "?" }
    let words = name.split(separator: " ").prefix(2)
    return words.compactMap { $0.first.map { String($0).uppercased() } }.joined()
}

// MARK: - Initials Avatar

private struct InitialsAvatar: View {
    let initials: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.7), Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initials)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProfileView()
            .environment(AuthManager.shared)
    }
}
