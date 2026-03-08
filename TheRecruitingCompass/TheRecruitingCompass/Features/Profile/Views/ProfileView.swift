import SwiftUI
import PhotosUI

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
            photoSection
            personalInfoSection
            emailSection
            passwordSection
            if isAthlete {
                athleteProfileSection
            }
            dataPrivacySection
        }
        .navigationTitle("My Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadInitialState()
        }
        .task {
            await viewModel.loadDeletionStatus()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.uploadPhoto(image)
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

    // MARK: - Section 1: Profile Photo

    private var photoSection: some View {
        Section {
            HStack(spacing: 16) {
                photoAvatar
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
                        .accessibilityLabel("Upload profile photo")

                        if user?.profilePhotoUrl != nil {
                            Button("Remove", role: .destructive) {
                                viewModel.showRemovePhotoConfirm = true
                            }
                            .font(.subheadline)
                            .accessibilityLabel("Remove profile photo")
                        }
                    }

                    if let error = viewModel.photoError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.errorRed)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private var photoAvatar: some View {
        if let urlString = user?.profilePhotoUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    initialsAvatar
                }
            }
        } else {
            initialsAvatar
        }
    }

    private var initialsAvatar: some View {
        let initials = userInitials(from: user?.fullName)
        return ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.7), Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initials)
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Section 2: Personal Information

    private var personalInfoSection: some View {
        Section {
            TextField("Full Name", text: $viewModel.fullName)
                .accessibilityLabel("Full name")

            TextField("Phone (optional)", text: $viewModel.phone)
                .keyboardType(.phonePad)
                .accessibilityLabel("Phone number")

            if isAthlete {
                DateOfBirthField(value: $viewModel.dateOfBirth)
            }

            if let msg = viewModel.personalInfoMessage {
                Label(msg.text, systemImage: msg.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(msg.isSuccess ? .primaryGreen : .errorRed)
                    .accessibilityLabel(msg.isSuccess ? "Saved successfully" : "Error: \(msg.text)")
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
            .accessibilityLabel(viewModel.isSavingPersonalInfo ? "Saving" : "Save personal information")

        } header: {
            Text("Personal Information")
        }
    }

    // MARK: - Section 3: Email

    private var emailSection: some View {
        Section {
            if let email = user?.email {
                HStack {
                    Text("Current:")
                        .foregroundColor(.secondary)
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
                .foregroundColor(.blue)
                .accessibilityLabel("Verification email sent. Check your inbox.")
            }

            if viewModel.isEmailFormExpanded {
                TextField("New Email Address", text: $viewModel.newEmail)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("New email address")

                SecureField("Current Password", text: $viewModel.emailCurrentPassword)
                    .textContentType(.password)
                    .accessibilityLabel("Current password to confirm email change")

                if let msg = viewModel.emailMessage {
                    Text(msg.text)
                        .font(.subheadline)
                        .foregroundColor(.errorRed)
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
                    .accessibilityLabel(viewModel.isSavingEmail ? "Updating email" : "Update email")

                    Button("Cancel") {
                        viewModel.isEmailFormExpanded = false
                        viewModel.newEmail = ""
                        viewModel.emailCurrentPassword = ""
                        viewModel.emailMessage = nil
                    }
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Cancel email change")
                }
            } else {
                Button("Change Email") {
                    viewModel.isEmailFormExpanded = true
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Change email address")
            }
        } header: {
            Text("Email Address")
        }
    }

    // MARK: - Section 4: Password

    private var passwordSection: some View {
        Section {
            SecureField("Current Password", text: $viewModel.currentPassword)
                .textContentType(.password)
                .accessibilityLabel("Current password")

            SecureField("New Password (min 8 characters)", text: $viewModel.newPassword)
                .textContentType(.newPassword)
                .accessibilityLabel("New password, minimum 8 characters")

            SecureField("Confirm New Password", text: $viewModel.confirmPassword)
                .textContentType(.newPassword)
                .accessibilityLabel("Confirm new password")

            if !viewModel.confirmPassword.isEmpty && !viewModel.passwordsMatch {
                Text("Passwords do not match.")
                    .font(.subheadline)
                    .foregroundColor(.errorRed)
                    .accessibilityLabel("Error: Passwords do not match")
            }

            if let msg = viewModel.passwordMessage {
                Label(msg.text, systemImage: msg.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(msg.isSuccess ? .primaryGreen : .errorRed)
                    .accessibilityLabel(msg.isSuccess ? msg.text : "Error: \(msg.text)")
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
            .accessibilityLabel(viewModel.isSavingPassword ? "Updating password" : "Update password")

        } header: {
            Text("Password")
        }
    }

    // MARK: - Section 5: Athlete Profile (athletes only)

    private var athleteProfileSection: some View {
        Section {
            NavigationLink {
                PlayerDetailsView(preferenceService: preferenceService, userRole: .player)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.green)
                        .cornerRadius(8)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Athlete Profile")
                            .font(.body.weight(.medium))
                        Text("Manage your recruiting profile — positions, stats, academic scores, and social handles.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 4)
            }
            .accessibilityLabel("Athlete Profile: Manage your recruiting profile")
        } header: {
            Text("Athlete Profile")
        }
    }

    // MARK: - Section 6: Data & Privacy

    private var dataPrivacySection: some View {
        Section {
            switch viewModel.deletionState {
            case .noRequest:
                deletionDefaultState

            case .confirmStep:
                deletionConfirmState

            case .pending(let scheduledFor):
                deletionPendingState(scheduledFor: scheduledFor)
            }

            if let error = viewModel.deletionError {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.errorRed)
                    .accessibilityLabel("Error: \(error)")
            }
        } header: {
            Text("Data & Privacy")
        }
    }

    private var deletionDefaultState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You can request deletion of your account and all associated data. Your account will be permanently deleted 30 days after your request, giving you time to change your mind.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                viewModel.beginDeletionRequest()
            } label: {
                Text("Request Account Deletion")
                    .fontWeight(.medium)
                    .foregroundColor(.errorRed)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.errorRed)
            .accessibilityLabel("Request account deletion")
        }
        .padding(.vertical, 4)
    }

    private var deletionConfirmState: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("This action cannot be easily undone.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.errorRed)

                VStack(alignment: .leading, spacing: 4) {
                    bulletItem("All your schools, coaches, interactions, and notes will be deleted")
                    bulletItem("You will be removed from any shared family units")
                    bulletItem("Your account will be permanently deleted after 30 days")
                    bulletItem("You may cancel within the 30-day window")
                }
            }
            .padding(12)
            .background(Color.errorRed.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

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
                .accessibilityLabel("Confirm account deletion")

                Button("Cancel") {
                    viewModel.cancelDeletionConfirm()
                }
                .foregroundColor(.secondary)
                .accessibilityLabel("Cancel account deletion")
            }
        }
        .padding(.vertical, 4)
    }

    private func deletionPendingState(scheduledFor: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your account is scheduled for deletion on \(scheduledFor.formatted(date: .long, time: .omitted)).")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.orange)
                Text("All your data will be permanently removed on that date. You can cancel this request before then.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

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
            .accessibilityLabel("Cancel account deletion request")
        }
        .padding(.vertical, 4)
    }

    private func bulletItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundColor(.errorRed)
            Text(text).font(.caption).foregroundColor(.primary)
        }
    }
}

// MARK: - Date of Birth Field

private struct DateOfBirthField: View {
    @Binding var value: String

    private var date: Binding<Date> {
        Binding(
            get: {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.date(from: value) ?? Date()
            },
            set: { newDate in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                value = formatter.string(from: newDate)
            }
        )
    }

    var body: some View {
        DatePicker(
            "Date of Birth",
            selection: date,
            in: ...Date(),
            displayedComponents: .date
        )
        .accessibilityLabel("Date of birth")
    }
}

// MARK: - Helpers

private func userInitials(from fullName: String?) -> String {
    guard let name = fullName, !name.isEmpty else { return "?" }
    let words = name.split(separator: " ").prefix(2)
    return words.compactMap { $0.first.map { String($0).uppercased() } }.joined()
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProfileView()
            .environment(AuthManager.shared)
    }
}
