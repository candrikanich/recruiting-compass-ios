import SwiftUI
import PhotosUI

struct PlayerDetailsView: View {
  @StateObject private var viewModel: PlayerDetailsViewModel
  @State private var selectedPhotoItem: PhotosPickerItem?

  init(preferenceService: PreferenceManaging, userRole: UserRole) {
    _viewModel = StateObject(wrappedValue: PlayerDetailsViewModel(
      preferenceService: preferenceService,
      userRole: userRole
    ))
  }

  var body: some View {
    Form {
      // Read-Only Banner
      if viewModel.isReadOnly {
        Section {
          HStack {
            Image(systemName: "info.circle.fill")
              .foregroundColor(.blue)
            Text("Read-Only Mode: Only players can edit their profile")
              .font(.callout)
          }
          .padding(.vertical, 4)
        }
      }

      // Profile Photo Section
      Section {
        VStack(spacing: 12) {
          if let image = viewModel.profileImage {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
              .frame(width: 120, height: 120)
              .clipShape(Circle())
          } else {
            Image(systemName: "person.crop.circle.fill")
              .resizable()
              .frame(width: 120, height: 120)
              .foregroundColor(.gray)
          }

          PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Label("Choose Photo", systemImage: "photo")
          }
          .disabled(viewModel.isReadOnly)
          .accessibilityLabel("Choose profile photo from library")
          .accessibilityHint(viewModel.isReadOnly ? "Profile editing is disabled" : "Opens photo library")
          .onChange(of: selectedPhotoItem) { newValue in
            Task {
              if let data = try? await newValue?.loadTransferable(type: Data.self),
                 let image = UIImage(data: data) {
                await viewModel.uploadProfilePhoto(image)
              }
            }
          }

          if viewModel.profileImage != nil {
            Button("Delete Photo", role: .destructive) {
              viewModel.showDeletePhotoConfirmation = true
            }
            .disabled(viewModel.isReadOnly)
            .accessibilityLabel("Delete profile photo")
            .accessibilityHint("Requires confirmation")
          }
        }
        .frame(maxWidth: .infinity, alignment: .center)
      } header: {
        Text("Profile Photo")
      }

      // Basic Information
      Section("Basic Information") {
        Picker("Graduation Year", selection: $viewModel.details.graduationYear) {
          Text("Select").tag(nil as Int?)
          ForEach(2024...2035, id: \.self) { year in
            Text("\(year)").tag(year as Int?)
          }
        }
        .disabled(viewModel.isReadOnly)

        TextField("High School", text: binding(for: \.highSchool))
          .disabled(viewModel.isReadOnly)

        TextField("Club Team", text: binding(for: \.clubTeam))
          .disabled(viewModel.isReadOnly)
      }

      // Athletic Profile
      Section("Athletic Profile") {
        TextField("Primary Sport", text: binding(for: \.primarySport))
          .disabled(viewModel.isReadOnly)

        TextField("Primary Position", text: binding(for: \.primaryPosition))
          .disabled(viewModel.isReadOnly)
      }

      // Physical Profile
      Section("Physical Profile") {
        Picker("Bats", selection: $viewModel.details.bats) {
          Text("Select").tag(nil as String?)
          Text("Right (R)").tag("R" as String?)
          Text("Left (L)").tag("L" as String?)
          Text("Switch (S)").tag("S" as String?)
        }
        .disabled(viewModel.isReadOnly)

        Picker("Throws", selection: $viewModel.details.throws_) {
          Text("Select").tag(nil as String?)
          Text("Right (R)").tag("R" as String?)
          Text("Left (L)").tag("L" as String?)
        }
        .disabled(viewModel.isReadOnly)

        HStack {
          Picker("Height (ft)", selection: Binding(
            get: { viewModel.heightFeet },
            set: { viewModel.updateHeight(feet: $0, inches: viewModel.heightInchesRemainder) }
          )) {
            ForEach(4...7, id: \.self) { feet in
              Text("\(feet) ft").tag(feet)
            }
          }
          .disabled(viewModel.isReadOnly)

          Picker("Height (in)", selection: Binding(
            get: { viewModel.heightInchesRemainder },
            set: { viewModel.updateHeight(feet: viewModel.heightFeet, inches: $0) }
          )) {
            ForEach(0...11, id: \.self) { inches in
              Text("\(inches) in").tag(inches)
            }
          }
          .disabled(viewModel.isReadOnly)
        }

        TextField("Weight (lbs)", value: $viewModel.details.weightLbs, format: .number)
          .keyboardType(.numberPad)
          .disabled(viewModel.isReadOnly)
      }

      // Academics
      Section("Academics") {
        TextField("GPA (0.0-5.0)", value: $viewModel.details.gpa, format: .number)
          .keyboardType(.decimalPad)
          .disabled(viewModel.isReadOnly)

        TextField("SAT Score (400-1600)", value: $viewModel.details.satScore, format: .number)
          .keyboardType(.numberPad)
          .disabled(viewModel.isReadOnly)

        TextField("ACT Score (1-36)", value: $viewModel.details.actScore, format: .number)
          .keyboardType(.numberPad)
          .disabled(viewModel.isReadOnly)
      }

      // External Profiles
      Section("External Profiles") {
        TextField("NCAA ID", text: binding(for: \.ncaaId))
          .disabled(viewModel.isReadOnly)

        TextField("Perfect Game ID", text: binding(for: \.perfectGameId))
          .disabled(viewModel.isReadOnly)

        TextField("Prep Baseball ID", text: binding(for: \.prepBaseballId))
          .disabled(viewModel.isReadOnly)
      }

      // Social Media
      Section("Social Media") {
        TextField("Twitter (@username)", text: binding(for: \.twitterHandle))
          .textInputAutocapitalization(.never)
          .disabled(viewModel.isReadOnly)

        TextField("Instagram (@username)", text: binding(for: \.instagramHandle))
          .textInputAutocapitalization(.never)
          .disabled(viewModel.isReadOnly)

        TextField("TikTok (@username)", text: binding(for: \.tiktokHandle))
          .textInputAutocapitalization(.never)
          .disabled(viewModel.isReadOnly)

        TextField("Facebook URL", text: binding(for: \.facebookUrl))
          .textInputAutocapitalization(.never)
          .keyboardType(.URL)
          .disabled(viewModel.isReadOnly)
      }

      // Contact Info
      Section("Contact Information") {
        TextField("Phone", text: binding(for: \.phone))
          .textContentType(.telephoneNumber)
          .keyboardType(.phonePad)
          .disabled(viewModel.isReadOnly)

        TextField("Email", text: binding(for: \.email))
          .textContentType(.emailAddress)
          .textInputAutocapitalization(.never)
          .keyboardType(.emailAddress)
          .disabled(viewModel.isReadOnly)

        Toggle("Allow coaches to see phone", isOn: binding(for: \.allowSharePhone, default: false))
          .disabled(viewModel.isReadOnly)

        Toggle("Allow coaches to see email", isOn: binding(for: \.allowShareEmail, default: false))
          .disabled(viewModel.isReadOnly)
      }

      // Current High School
      Section("Current High School") {
        TextField("School Name", text: binding(for: \.schoolName))
          .disabled(viewModel.isReadOnly)

        TextField("Address", text: binding(for: \.schoolAddress))
          .disabled(viewModel.isReadOnly)

        TextField("City", text: binding(for: \.schoolCity))
          .disabled(viewModel.isReadOnly)

        TextField("State (2 letters)", text: binding(for: \.schoolState))
          .textInputAutocapitalization(.characters)
          .disabled(viewModel.isReadOnly)
      }

      // High School Teams (Expandable by Grade)
      DisclosureGroup("9th Grade Team") {
        TextField("Team Name", text: binding(for: \.ninthGradeTeam))
          .disabled(viewModel.isReadOnly)
        TextField("Coach Name", text: binding(for: \.ninthGradeCoach))
          .disabled(viewModel.isReadOnly)
      }

      DisclosureGroup("10th Grade Team") {
        TextField("Team Name", text: binding(for: \.tenthGradeTeam))
          .disabled(viewModel.isReadOnly)
        TextField("Coach Name", text: binding(for: \.tenthGradeCoach))
          .disabled(viewModel.isReadOnly)
      }

      DisclosureGroup("11th Grade Team") {
        TextField("Team Name", text: binding(for: \.eleventhGradeTeam))
          .disabled(viewModel.isReadOnly)
        TextField("Coach Name", text: binding(for: \.eleventhGradeCoach))
          .disabled(viewModel.isReadOnly)
      }

      DisclosureGroup("12th Grade Team") {
        TextField("Team Name", text: binding(for: \.twelfthGradeTeam))
          .disabled(viewModel.isReadOnly)
        TextField("Coach Name", text: binding(for: \.twelfthGradeCoach))
          .disabled(viewModel.isReadOnly)
      }

      // Travel Team
      Section("Travel Team") {
        TextField("Year", value: $viewModel.details.travelTeamYear, format: .number)
          .keyboardType(.numberPad)
          .disabled(viewModel.isReadOnly)

        TextField("Team Name", text: binding(for: \.travelTeamName))
          .disabled(viewModel.isReadOnly)

        TextField("Coach Name", text: binding(for: \.travelTeamCoach))
          .disabled(viewModel.isReadOnly)
      }
    }
    .navigationTitle("Player Details")
    .toolbar {
      if !viewModel.isReadOnly {
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task {
              await viewModel.saveDetails()
            }
          }
          .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)
        }
      }
    }
    .overlay {
      PreferenceLoadingOverlay(
        isLoading: viewModel.isLoading,
        message: "Loading details..."
      )
    }
    .preferenceErrorAlert(errorMessage: $viewModel.errorMessage)
    .alert("Delete Profile Photo?", isPresented: $viewModel.showDeletePhotoConfirmation) {
      Button("Cancel", role: .cancel) { }
      Button("Delete", role: .destructive) {
        Task {
          await viewModel.deleteProfilePhoto()
        }
      }
    } message: {
      Text("This action cannot be undone.")
    }
    .overlay(alignment: .top) {
      PreferenceSuccessToast(message: viewModel.successMessage)
    }
    .task {
      await viewModel.loadDetails()
    }
  }

  // MARK: - Binding Helpers

  private func binding(for keyPath: WritableKeyPath<PlayerDetails, String?>) -> Binding<String> {
    Binding(
      get: { viewModel.details[keyPath: keyPath] ?? "" },
      set: { newValue in
        viewModel.details[keyPath: keyPath] = newValue.isEmpty ? nil : newValue
        viewModel.markChanged()
      }
    )
  }

  private func binding(for keyPath: WritableKeyPath<PlayerDetails, Bool?>, default defaultValue: Bool) -> Binding<Bool> {
    Binding(
      get: { viewModel.details[keyPath: keyPath] ?? defaultValue },
      set: { newValue in
        viewModel.details[keyPath: keyPath] = newValue
        viewModel.markChanged()
      }
    )
  }
}

struct PlayerDetailsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      PlayerDetailsView(
        preferenceService: PreferencePreviewMock(defaultValue: PlayerDetails.default),
        userRole: .player
      )
    }
  }
}
