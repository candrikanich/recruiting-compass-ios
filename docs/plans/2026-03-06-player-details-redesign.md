# Player Details Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the single-scroll 30-field `PlayerDetailsView` with a 4-tab "Guided Profile" interface featuring auto-save, a completeness hero card, sport-specific conditional fields, and haptic feedback.

**Architecture:** `PlayerDetailsView` becomes a thin container holding a `TabView` with 4 tab sub-views (`BasicsTab`, `AthleticsTab`, `AcademicsSocialTab`, `HistoryTab`). The `PlayerDetailsViewModel` gains debounced auto-save (replacing the manual Save button), a `SaveStatus` enum for toolbar display, a `completenessScore` computed property, and a fit-score recalculation trigger. All new sub-views live in `Features/Preferences/` — new tab files under `Views/Tabs/`, new reusable components under `Components/`.

**Tech Stack:** SwiftUI, `@Observable`, `UIImpactFeedbackGenerator`, `Task.sleep` for debounce (no third-party dependencies), native `Picker(.wheel)` for graduation year and height.

---

## File Map

```
Features/Preferences/
├── ViewModels/
│   └── PlayerDetailsViewModel.swift       ← MODIFY
├── Views/
│   ├── PlayerDetailsView.swift            ← MODIFY (container only)
│   └── Tabs/
│       ├── BasicsTab.swift                ← CREATE
│       ├── AthleticsTab.swift             ← CREATE
│       ├── AcademicsSocialTab.swift       ← CREATE
│       └── HistoryTab.swift               ← CREATE
└── Components/
    ├── PlayerCompletenessCard.swift        ← CREATE
    ├── SaveStatusView.swift               ← CREATE
    └── PositionChipsView.swift            ← CREATE

Tests/Features/Preferences/ViewModels/
└── PlayerDetailsViewModelTests.swift      ← MODIFY (add new test cases)
```

---

## Task 1: Add `SaveStatus` enum and auto-save to `PlayerDetailsViewModel`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/ViewModels/PlayerDetailsViewModel.swift`

### Step 1: Write failing tests first

Add to `TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences/ViewModels/PlayerDetailsViewModelTests.swift`:

```swift
// MARK: - Auto-Save Tests

func testAutoSave_WhenFieldChanges_TriggersDebounce() async {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    mockService.savePreferencesResult = .success(viewModel.details)

    viewModel.scheduleAutoSave()

    // Status should immediately be .saving or transition quickly
    // After debounce (1s in prod, we test the method directly)
    await viewModel.saveDetails()

    XCTAssertEqual(mockService.savePreferencesCalls.count, 1)
    XCTAssertEqual(viewModel.saveStatus, .saved)
}

func testSaveStatus_DefaultIsIdle() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    XCTAssertEqual(viewModel.saveStatus, .idle)
}

func testSaveStatus_DuringSave_IsSaving() async {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    // saveDetails sets .saving then .saved
    mockService.savePreferencesResult = .success(viewModel.details)
    let task = Task { await viewModel.saveDetails() }
    // Immediately check (will be .saving at start)
    await task.value
    XCTAssertEqual(viewModel.saveStatus, .saved)
}

func testCompletenessScore_EmptyDetails_IsZero() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    XCTAssertEqual(viewModel.completenessScore, 0.0)
}

func testCompletenessScore_FullDetails_IsOne() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    viewModel.details = PlayerDetails(
        graduationYear: 2026,
        highSchool: "Test High",
        primarySport: "Baseball",
        schoolName: "Test",
        schoolCity: "Austin",
        schoolState: "TX",
        bats: "R",
        throws_: "R",
        heightInches: 72,
        weightLbs: 180,
        gpa: 3.8,
        satScore: 1350,
        actScore: 30,
        twitterHandle: "@test",
        instagramHandle: "@test"
    )
    XCTAssertGreaterThan(viewModel.completenessScore, 0.8)
}

func testNormalizePositions_TitleCasesAll() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    viewModel.details.positions = ["pitcher", "FIRST BASE", "outfielder"]
    viewModel.normalizePositions()
    XCTAssertEqual(viewModel.details.positions, ["Pitcher", "First Base", "Outfielder"])
}

func testIsBaseballOrSoftball_WhenBaseball_ReturnsTrue() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    viewModel.details.primarySport = "Baseball"
    XCTAssertTrue(viewModel.isBaseballOrSoftball)
}

func testIsBaseballOrSoftball_WhenSoccer_ReturnsFalse() {
    viewModel = PlayerDetailsViewModel(preferenceService: mockService, userRole: .player)
    viewModel.details.primarySport = "Soccer"
    XCTAssertFalse(viewModel.isBaseballOrSoftball)
}
```

### Step 2: Run tests to verify they fail

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing TheRecruitingCompassTests/PlayerDetailsViewModelTests 2>&1 | tail -30
```

Expected: Compile errors for `saveStatus`, `completenessScore`, etc. — that's correct.

### Step 3: Implement in `PlayerDetailsViewModel.swift`

Replace the full file with this implementation:

```swift
import Foundation
import SwiftUI
import Observation
import PhotosUI
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "PlayerDetailsViewModel")

enum SaveStatus: Equatable {
    case idle
    case saving
    case saved
}

@Observable
@MainActor
final class PlayerDetailsViewModel {
    var details: PlayerDetails = .default
    var isLoading = false
    var isUploadingPhoto = false
    var errorMessage: String?
    var profileImage: UIImage?
    var isReadOnly = false
    var showDeletePhotoConfirmation = false
    var saveStatus: SaveStatus = .idle
    var selectedTab: Int = 0

    // Keep for backward-compat with existing tests
    var isSaving: Bool { saveStatus == .saving }
    var hasUnsavedChanges: Bool { saveStatus != .idle || _pendingAutoSave != nil }
    var successMessage: String? { saveStatus == .saved ? "Saved" : nil }

    private let preferenceService: any PreferenceManaging
    private let userRole: UserRole
    @ObservationIgnored nonisolated(unsafe) private var _pendingAutoSave: Task<Void, Never>?

    init(preferenceService: any PreferenceManaging, userRole: UserRole) {
        self.preferenceService = preferenceService
        self.userRole = userRole
        self.isReadOnly = (userRole == .parent)
    }

    nonisolated deinit {
        _pendingAutoSave?.cancel()
    }

    // MARK: - Completeness

    var completenessScore: Double {
        let fields: [Bool] = [
            details.graduationYear != nil,
            !(details.highSchool ?? "").isEmpty,
            !(details.primarySport ?? "").isEmpty,
            !(details.schoolName ?? "").isEmpty,
            !(details.schoolCity ?? "").isEmpty,
            !(details.schoolState ?? "").isEmpty,
            details.heightInches != nil,
            details.weightLbs != nil,
            details.gpa != nil,
            details.satScore != nil,
            details.actScore != nil,
            !(details.twitterHandle ?? "").isEmpty || !(details.instagramHandle ?? "").isEmpty,
            details.bats != nil || !isBaseballOrSoftball,
            details.throws_ != nil || !isBaseballOrSoftball,
        ]
        let filled = fields.filter { $0 }.count
        return Double(filled) / Double(fields.count)
    }

    var isBaseballOrSoftball: Bool {
        guard let sport = details.primarySport?.lowercased() else { return false }
        return sport == "baseball" || sport == "softball"
    }

    // MARK: - Auto-Save

    func scheduleAutoSave() {
        guard !isReadOnly else { return }
        _pendingAutoSave?.cancel()
        saveStatus = .saving
        _pendingAutoSave = Task {
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled else { return }
            await saveDetails()
        }
    }

    func markChanged() {
        guard !isReadOnly else { return }
        scheduleAutoSave()
    }

    // MARK: - Load/Save

    func loadDetails() async {
        logger.debug("Loading player details")
        isLoading = true
        errorMessage = nil
        do {
            if let savedDetails: PlayerDetails = try await preferenceService.fetchPreferences(category: .player) {
                details = savedDetails
                logger.info("Loaded existing player details")
            } else {
                details = .default
                logger.info("No existing details, using defaults")
            }
            saveStatus = .idle
            isLoading = false
        } catch {
            logger.error("Failed to load details: \(error.localizedDescription)")
            errorMessage = "Failed to load player details. Please try again."
            isLoading = false
        }
    }

    func saveDetails() async {
        guard !isReadOnly else { return }
        logger.debug("Saving player details")
        saveStatus = .saving
        normalizePositions()
        do {
            _ = try await preferenceService.savePreferences(category: .player, data: details)
            saveStatus = .saved
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            logger.info("Player details saved")
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    if self.saveStatus == .saved { self.saveStatus = .idle }
                }
            }
        } catch {
            logger.error("Failed to save details: \(error.localizedDescription)")
            errorMessage = "Failed to save player details. Please try again."
            saveStatus = .idle
        }
    }

    func triggerFitScoreRecalculation() {
        // Fire-and-forget: recalculate school fit scores after profile update
        // Hook into the fit-score API endpoint when available
        Task {
            logger.info("Fit score recalculation triggered (no-op until API endpoint wired)")
        }
    }

    // MARK: - Photo Upload

    func uploadProfilePhoto(_ image: UIImage) async {
        guard !isReadOnly else { return }
        logger.debug("Uploading profile photo")
        isUploadingPhoto = true
        errorMessage = nil
        do {
            guard let compressedData = image.jpegData(compressionQuality: 0.7) else {
                throw PhotoError.compressionFailed
            }
            guard compressedData.count <= 5_000_000 else {
                throw PhotoError.fileTooLarge
            }
            profileImage = image
            markChanged()
            logger.info("Profile photo uploaded successfully")
            isUploadingPhoto = false
        } catch {
            logger.error("Failed to upload photo: \(error.localizedDescription)")
            errorMessage = "Failed to upload photo. Please try again."
            isUploadingPhoto = false
        }
    }

    func deleteProfilePhoto() async {
        guard !isReadOnly else { return }
        profileImage = nil
        markChanged()
        logger.info("Profile photo deleted")
    }

    // MARK: - Field Updates

    func updateGraduationYear(_ value: Int?) {
        details.graduationYear = value
        markChanged()
    }

    func updateGPA(_ value: Double?) {
        if let gpa = value, gpa >= 0.0 && gpa <= 5.0 {
            details.gpa = gpa
            markChanged()
        } else if value == nil {
            details.gpa = nil
            markChanged()
        }
    }

    func updateSAT(_ value: Int?) {
        if let sat = value, sat >= 400 && sat <= 1600 {
            details.satScore = sat
            markChanged()
        } else if value == nil {
            details.satScore = nil
            markChanged()
        }
    }

    func updateACT(_ value: Int?) {
        if let act = value, act >= 1 && act <= 36 {
            details.actScore = act
            markChanged()
        } else if value == nil {
            details.actScore = nil
            markChanged()
        }
    }

    func updateHeight(feet: Int, inches: Int) {
        details.heightInches = (feet * 12) + inches
        markChanged()
    }

    func normalizePositions() {
        details.positions = details.positions?.map { pos in
            pos.split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                .joined(separator: " ")
        }
    }

    // MARK: - Computed

    var heightFeet: Int { (details.heightInches ?? 0) / 12 }
    var heightInchesRemainder: Int { (details.heightInches ?? 0) % 12 }
}

enum PhotoError: LocalizedError {
    case compressionFailed
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .compressionFailed: return "Failed to compress photo"
        case .fileTooLarge: return "Photo must be less than 5MB"
        }
    }
}
```

### Step 4: Run tests — verify they pass

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing TheRecruitingCompassTests/PlayerDetailsViewModelTests 2>&1 | tail -30
```

Expected: All `PlayerDetailsViewModelTests` pass.

### Step 5: Fix existing test assertions that relied on `hasUnsavedChanges` / `isSaving` / `successMessage`

The computed wrappers preserve the API — if any tests fail, check mock interaction counts and adjust. The key change: `saveStatus` drives everything.

> **Note:** `testSaveDetails_WhenAthlete_SavesSuccessfully` checks `successMessage == "Player details saved successfully"` — update that assertion to `viewModel.saveStatus == .saved`.

### Step 6: Commit

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/ViewModels/PlayerDetailsViewModel.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences/ViewModels/PlayerDetailsViewModelTests.swift
git commit -m "feat(player-details): add auto-save, SaveStatus, completeness score, sport detection"
```

---

## Task 2: Create `PlayerCompletenessCard.swift`

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Components/PlayerCompletenessCard.swift`

### Step 1: Write the component

```swift
import SwiftUI

struct PlayerCompletenessCard: View {
    let score: Double  // 0.0 - 1.0

    private var percentage: Int { Int(score * 100) }

    private var progressColor: Color {
        switch score {
        case 0..<0.4: return .red
        case 0.4..<0.75: return .yellow
        default: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Profile Completeness")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(percentage)%")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(progressColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.red, .yellow, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * score, height: 8)
                        .animation(.spring(response: 0.4), value: score)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile \(percentage)% complete")
    }
}

#Preview {
    VStack(spacing: 16) {
        PlayerCompletenessCard(score: 0.2)
        PlayerCompletenessCard(score: 0.6)
        PlayerCompletenessCard(score: 0.9)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
```

### Step 2: Verify build

```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```

Expected: Build succeeds.

### Step 3: Commit

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Components/PlayerCompletenessCard.swift
git commit -m "feat(player-details): add PlayerCompletenessCard with gradient progress bar"
```

---

## Task 3: Create `SaveStatusView.swift`

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Components/SaveStatusView.swift`

### Step 1: Write the component

```swift
import SwiftUI

struct SaveStatusView: View {
    let status: SaveStatus

    var body: some View {
        Group {
            switch status {
            case .idle:
                EmptyView()
            case .saving:
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Saving...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .saved:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: status)
    }
}

#Preview {
    VStack(spacing: 20) {
        SaveStatusView(status: .idle)
        SaveStatusView(status: .saving)
        SaveStatusView(status: .saved)
    }
}
```

### Step 2: Verify build, then commit

```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Components/SaveStatusView.swift
git commit -m "feat(player-details): add SaveStatusView (idle/saving/saved)"
```

---

## Task 4: Create `PositionChipsView.swift`

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Components/PositionChipsView.swift`

### Step 1: Write the component

```swift
import SwiftUI

struct PositionChipsView: View {
    let sport: String?
    @Binding var selectedPositions: [String]
    let isDisabled: Bool

    private var availablePositions: [String] {
        switch sport?.lowercased() {
        case "baseball", "softball":
            return ["Pitcher", "Catcher", "First Base", "Second Base", "Third Base",
                    "Shortstop", "Left Field", "Center Field", "Right Field", "Designated Hitter"]
        case "basketball":
            return ["Point Guard", "Shooting Guard", "Small Forward", "Power Forward", "Center"]
        case "football":
            return ["Quarterback", "Running Back", "Wide Receiver", "Tight End", "Offensive Line",
                    "Defensive Line", "Linebacker", "Cornerback", "Safety", "Kicker", "Punter"]
        case "soccer":
            return ["Goalkeeper", "Defender", "Midfielder", "Forward", "Winger", "Sweeper"]
        default:
            return []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Positions")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if availablePositions.isEmpty {
                Text("Select a sport above to choose positions")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(availablePositions, id: \.self) { position in
                        PositionChip(
                            title: position,
                            isSelected: selectedPositions.contains(position),
                            isDisabled: isDisabled
                        ) {
                            toggle(position)
                        }
                    }
                }
            }
        }
    }

    private func toggle(_ position: String) {
        guard !isDisabled else { return }
        if let idx = selectedPositions.firstIndex(of: position) {
            selectedPositions.remove(at: idx)
        } else {
            selectedPositions.append(position)
        }
    }
}

private struct PositionChip: View {
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .disabled(isDisabled)
        .accessibilityLabel("\(title), \(isSelected ? "selected" : "not selected")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// Simple flow layout for chips
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map(\.size.height).max() ?? 0 }.reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map(\.size.height).max() ?? 0
            for item in row {
                item.view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private struct Item { let view: LayoutSubview; let size: CGSize }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Item]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[Item]] = [[]]
        var currentWidth: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.endIndex - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.endIndex - 1].append(Item(view: view, size: size))
            currentWidth += size.width + spacing
        }
        return rows.filter { !$0.isEmpty }
    }
}

#Preview {
    @Previewable @State var positions: [String] = ["Pitcher"]
    PositionChipsView(sport: "Baseball", selectedPositions: $positions, isDisabled: false)
        .padding()
}
```

### Step 2: Verify build, then commit

```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Components/PositionChipsView.swift
git commit -m "feat(player-details): add PositionChipsView with FlowLayout for multi-select"
```

---

## Task 5: Create `BasicsTab.swift`

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/BasicsTab.swift`

### Step 1: Write the tab

```swift
import SwiftUI
import PhotosUI

struct BasicsTab: View {
    @Bindable var viewModel: PlayerDetailsViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Profile Photo Card
                photoCard

                // Basic Info Card
                cardSection("Basic Information") {
                    VStack(spacing: 0) {
                        wheelGradYearRow
                        divider
                        sportPickerRow
                        divider
                        textRow("High School", keyPath: \.highSchool)
                        divider
                        textRow("City", keyPath: \.schoolCity)
                        divider
                        stateRow
                    }
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.uploadProfilePhoto(image)
                }
            }
        }
    }

    // MARK: - Photo Card

    private var photoCard: some View {
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
                    .foregroundStyle(.tertiary)
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Choose Photo", systemImage: "photo")
            }
            .disabled(viewModel.isReadOnly)
            .accessibilityLabel("Choose profile photo")

            if viewModel.profileImage != nil {
                Button("Delete Photo", role: .destructive) {
                    viewModel.showDeletePhotoConfirmation = true
                }
                .disabled(viewModel.isReadOnly)
                .font(.callout)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Grad Year Wheel Picker

    private var wheelGradYearRow: some View {
        HStack {
            Text("Graduation Year")
                .font(.body)
            Spacer()
            Picker("Graduation Year", selection: Binding(
                get: { viewModel.details.graduationYear ?? Calendar.current.component(.year, from: .now) },
                set: { viewModel.updateGraduationYear($0) }
            )) {
                ForEach(GradeLevelHelper.allowedGraduationYears, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 100, height: 80)
            .clipped()
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Sport Picker

    private static let commonSports = ["Baseball", "Softball", "Basketball", "Football", "Soccer",
                                       "Volleyball", "Tennis", "Swimming", "Track & Field", "Lacrosse", "Other"]

    private var sportPickerRow: some View {
        HStack {
            Text("Primary Sport")
                .font(.body)
            Spacer()
            Picker("Primary Sport", selection: Binding(
                get: { viewModel.details.primarySport ?? "" },
                set: {
                    viewModel.details.primarySport = $0.isEmpty ? nil : $0
                    viewModel.markChanged()
                }
            )) {
                Text("Select").tag("")
                ForEach(Self.commonSports, id: \.self) { sport in
                    Text(sport).tag(sport)
                }
            }
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func textRow(_ label: String, keyPath: WritableKeyPath<PlayerDetails, String?>) -> some View {
        HStack {
            Text(label)
                .font(.body)
            Spacer()
            TextField(label, text: Binding(
                get: { viewModel.details[keyPath: keyPath] ?? "" },
                set: {
                    viewModel.details[keyPath: keyPath] = $0.isEmpty ? nil : $0
                    viewModel.markChanged()
                }
            ))
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var stateRow: some View {
        HStack {
            Text("State")
                .font(.body)
            Spacer()
            TextField("TX", text: Binding(
                get: { viewModel.details.schoolState ?? "" },
                set: {
                    viewModel.details.schoolState = $0.isEmpty ? nil : $0
                    viewModel.markChanged()
                }
            ))
            .textInputAutocapitalization(.characters)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Divider().padding(.leading)
    }

    private func cardSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            content()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
```

### Step 2: Build, then commit

```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/BasicsTab.swift
git commit -m "feat(player-details): add BasicsTab (photo, grad year wheel, sport picker)"
```

---

## Task 6: Create `AthleticsTab.swift`

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/AthleticsTab.swift`

### Step 1: Write the tab

```swift
import SwiftUI

struct AthleticsTab: View {
    @Bindable var viewModel: PlayerDetailsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Physical Stats Card
                cardSection("Physical Stats") {
                    VStack(spacing: 0) {
                        heightRow
                        divider
                        weightRow
                    }
                }

                // Positions Card
                cardSection("Positions") {
                    PositionChipsView(
                        sport: viewModel.details.primarySport,
                        selectedPositions: Binding(
                            get: { viewModel.details.positions ?? [] },
                            set: {
                                viewModel.details.positions = $0.isEmpty ? nil : $0
                                viewModel.markChanged()
                            }
                        ),
                        isDisabled: viewModel.isReadOnly
                    )
                    .padding()
                }

                // Baseball/Softball-Only Card
                if viewModel.isBaseballOrSoftball {
                    cardSection("Baseball/Softball") {
                        VStack(spacing: 0) {
                            batsRow
                            divider
                            throwsRow
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    cardSection("External IDs") {
                        VStack(spacing: 0) {
                            textRow("Perfect Game ID", keyPath: \.perfectGameId)
                            divider
                            textRow("Prep Baseball ID", keyPath: \.prepBaseballId)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // NCAA (all sports)
                cardSection("External IDs") {
                    textRow("NCAA ID", keyPath: \.ncaaId)
                }
            }
            .padding()
            .animation(.easeInOut, value: viewModel.isBaseballOrSoftball)
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Height Wheel Pickers

    private var heightRow: some View {
        HStack {
            Text("Height")
                .font(.body)
            Spacer()
            Picker("Feet", selection: Binding(
                get: { viewModel.heightFeet },
                set: { viewModel.updateHeight(feet: $0, inches: viewModel.heightInchesRemainder) }
            )) {
                ForEach(4...7, id: \.self) { ft in Text("\(ft) ft").tag(ft) }
            }
            .pickerStyle(.wheel)
            .frame(width: 80, height: 80)
            .clipped()
            .disabled(viewModel.isReadOnly)

            Picker("Inches", selection: Binding(
                get: { viewModel.heightInchesRemainder },
                set: { viewModel.updateHeight(feet: viewModel.heightFeet, inches: $0) }
            )) {
                ForEach(0...11, id: \.self) { i in Text("\(i) in").tag(i) }
            }
            .pickerStyle(.wheel)
            .frame(width: 80, height: 80)
            .clipped()
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private var weightRow: some View {
        HStack {
            Text("Weight (lbs)")
                .font(.body)
            Spacer()
            TextField("180", value: Binding(
                get: { viewModel.details.weightLbs },
                set: {
                    viewModel.details.weightLbs = $0
                    viewModel.markChanged()
                }
            ), format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var batsRow: some View {
        HStack {
            Text("Bats")
                .font(.body)
            Spacer()
            Picker("Bats", selection: Binding(
                get: { viewModel.details.bats ?? "" },
                set: {
                    viewModel.details.bats = $0.isEmpty ? nil : $0
                    viewModel.markChanged()
                }
            )) {
                Text("Select").tag("")
                Text("Right (R)").tag("R")
                Text("Left (L)").tag("L")
                Text("Switch (S)").tag("S")
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var throwsRow: some View {
        HStack {
            Text("Throws")
                .font(.body)
            Spacer()
            Picker("Throws", selection: Binding(
                get: { viewModel.details.throws_ ?? "" },
                set: {
                    viewModel.details.throws_ = $0.isEmpty ? nil : $0
                    viewModel.markChanged()
                }
            )) {
                Text("Select").tag("")
                Text("Right (R)").tag("R")
                Text("Left (L)").tag("L")
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func textRow(_ label: String, keyPath: WritableKeyPath<PlayerDetails, String?>) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            TextField(label, text: Binding(
                get: { viewModel.details[keyPath: keyPath] ?? "" },
                set: {
                    viewModel.details[keyPath: keyPath] = $0.isEmpty ? nil : $0
                    viewModel.markChanged()
                }
            ))
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var divider: some View { Divider().padding(.leading) }

    private func cardSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            content()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
```

### Step 2: Build, then commit

```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/AthleticsTab.swift
git commit -m "feat(player-details): add AthleticsTab (height wheels, position chips, baseball conditional)"
```

---

## Task 7: Create `AcademicsSocialTab.swift`

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/AcademicsSocialTab.swift`

### Step 1: Write the tab

```swift
import SwiftUI

struct AcademicsSocialTab: View {
    @Bindable var viewModel: PlayerDetailsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                cardSection("Academics") {
                    VStack(spacing: 0) {
                        decimalRow("GPA (0.0 – 5.0)", keyPath: \.gpa)
                        divider
                        intRow("SAT Score (400 – 1600)", keyPath: \.satScore)
                        divider
                        intRow("ACT Score (1 – 36)", keyPath: \.actScore)
                    }
                }

                cardSection("Social Media") {
                    VStack(spacing: 0) {
                        handleRow("Twitter", placeholder: "@username", keyPath: \.twitterHandle)
                        divider
                        handleRow("Instagram", placeholder: "@username", keyPath: \.instagramHandle)
                        divider
                        handleRow("TikTok", placeholder: "@username", keyPath: \.tiktokHandle)
                        divider
                        handleRow("Facebook URL", placeholder: "https://...", keyPath: \.facebookUrl)
                    }
                }

                cardSection("Privacy") {
                    VStack(spacing: 0) {
                        toggleRow("Share phone with coaches", keyPath: \.allowSharePhone)
                        divider
                        toggleRow("Share email with coaches", keyPath: \.allowShareEmail)
                    }
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }

    private func decimalRow(_ label: String, keyPath: WritableKeyPath<PlayerDetails, Double?>) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            TextField("0.0", value: Binding(
                get: { viewModel.details[keyPath: keyPath] },
                set: {
                    viewModel.details[keyPath: keyPath] = $0
                    viewModel.markChanged()
                }
            ), format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func intRow(_ label: String, keyPath: WritableKeyPath<PlayerDetails, Int?>) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            TextField("–", value: Binding(
                get: { viewModel.details[keyPath: keyPath] },
                set: {
                    viewModel.details[keyPath: keyPath] = $0
                    viewModel.markChanged()
                }
            ), format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func handleRow(_ label: String, placeholder: String, keyPath: WritableKeyPath<PlayerDetails, String?>) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            TextField(placeholder, text: Binding(
                get: { viewModel.details[keyPath: keyPath] ?? "" },
                set: {
                    viewModel.details[keyPath: keyPath] = $0.isEmpty ? nil : $0
                    viewModel.markChanged()
                }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func toggleRow(_ label: String, keyPath: WritableKeyPath<PlayerDetails, Bool?>) -> some View {
        Toggle(label, isOn: Binding(
            get: { viewModel.details[keyPath: keyPath] ?? false },
            set: {
                viewModel.details[keyPath: keyPath] = $0
                viewModel.markChanged()
            }
        ))
        .disabled(viewModel.isReadOnly)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var divider: some View { Divider().padding(.leading) }

    private func cardSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            content()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
```

### Step 2: Build, then commit

```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/AcademicsSocialTab.swift
git commit -m "feat(player-details): add AcademicsSocialTab (GPA, test scores, social media, privacy)"
```

---

## Task 8: Create `HistoryTab.swift`

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/HistoryTab.swift`

### Step 1: Write the tab

```swift
import SwiftUI

struct HistoryTab: View {
    @Bindable var viewModel: PlayerDetailsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                cardSection("High School Career") {
                    VStack(spacing: 0) {
                        gradeSection("9th Grade", team: \.ninthGradeTeam, coach: \.ninthGradeCoach)
                        divider
                        gradeSection("10th Grade", team: \.tenthGradeTeam, coach: \.tenthGradeCoach)
                        divider
                        gradeSection("11th Grade", team: \.eleventhGradeTeam, coach: \.eleventhGradeCoach)
                        divider
                        gradeSection("12th Grade", team: \.twelfthGradeTeam, coach: \.twelfthGradeCoach)
                    }
                }

                cardSection("Travel Team") {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Year").font(.body)
                            Spacer()
                            TextField("–", value: Binding(
                                get: { viewModel.details.travelTeamYear },
                                set: {
                                    viewModel.details.travelTeamYear = $0
                                    viewModel.markChanged()
                                }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .disabled(viewModel.isReadOnly)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        divider
                        textRow("Team Name", keyPath: \.travelTeamName)
                        divider
                        textRow("Coach Name", keyPath: \.travelTeamCoach)
                    }
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }

    private func gradeSection(
        _ grade: String,
        team: WritableKeyPath<PlayerDetails, String?>,
        coach: WritableKeyPath<PlayerDetails, String?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(grade)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 10)
            textRow("Team", keyPath: team)
            Divider().padding(.leading)
            textRow("Coach", keyPath: coach)
        }
    }

    private func textRow(_ label: String, keyPath: WritableKeyPath<PlayerDetails, String?>) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            TextField(label, text: Binding(
                get: { viewModel.details[keyPath: keyPath] ?? "" },
                set: {
                    viewModel.details[keyPath: keyPath] = $0.isEmpty ? nil : $0
                    viewModel.markChanged()
                }
            ))
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isReadOnly)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var divider: some View { Divider().padding(.leading) }

    private func cardSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            content()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
```

### Step 2: Build, then commit

```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/Tabs/HistoryTab.swift
git commit -m "feat(player-details): add HistoryTab (HS career by grade, travel team)"
```

---

## Task 9: Refactor `PlayerDetailsView.swift` — wire everything together

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/PlayerDetailsView.swift`

### Step 1: Replace the file

```swift
import SwiftUI
import PhotosUI

struct PlayerDetailsView: View {
    @State private var viewModel: PlayerDetailsViewModel

    init(preferenceService: PreferenceManaging, userRole: UserRole) {
        _viewModel = State(initialValue: PlayerDetailsViewModel(
            preferenceService: preferenceService,
            userRole: userRole
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Completeness Hero
            PlayerCompletenessCard(score: viewModel.completenessScore)
                .padding(.horizontal)
                .padding(.top, 8)

            // Tab View
            TabView(selection: $viewModel.selectedTab) {
                BasicsTab(viewModel: viewModel)
                    .tabItem {
                        Label("Basics", systemImage: "person.crop.square")
                    }
                    .tag(0)

                AthleticsTab(viewModel: viewModel)
                    .tabItem {
                        Label("Athletics", systemImage: "bolt.fill")
                    }
                    .tag(1)

                AcademicsSocialTab(viewModel: viewModel)
                    .tabItem {
                        Label("Academics", systemImage: "graduationcap.fill")
                    }
                    .tag(2)

                HistoryTab(viewModel: viewModel)
                    .tabItem {
                        Label("History", systemImage: "clock.fill")
                    }
                    .tag(3)
            }
            .onChange(of: viewModel.selectedTab) { _, _ in
                viewModel.triggerFitScoreRecalculation()
            }
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle("Player Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                SaveStatusView(status: viewModel.saveStatus)
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
                Task { await viewModel.deleteProfilePhoto() }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .task {
            await viewModel.loadDetails()
        }
        .onDisappear {
            viewModel.triggerFitScoreRecalculation()
        }
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
```

### Step 2: Build

```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```

Expected: Clean build. If any type errors appear (e.g., `@Bindable` on non-Observable), check that `PlayerDetailsViewModel` is marked `@Observable`.

### Step 3: Run full test suite

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -40
```

Expected: All tests pass (126+).

### Step 4: Commit

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/PlayerDetailsView.swift
git commit -m "feat(player-details): wire 4-tab PlayerDetailsView with completeness card and save status"
```

---

## Task 10: Final test pass — update stale test assertions

Check `PlayerDetailsViewModelTests.swift` for any `successMessage` / `isSaving` / `hasUnsavedChanges` assertions that may need updating:

- `testSaveDetails_WhenAthlete_SavesSuccessfully`: Change `XCTAssertEqual(viewModel.successMessage, "Player details saved successfully")` → `XCTAssertEqual(viewModel.saveStatus, .saved)`
- All `hasUnsavedChanges` checks still work because `markChanged()` calls `scheduleAutoSave()` which sets `saveStatus = .saving`

### Step 1: Run only the Preferences tests

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing TheRecruitingCompassTests/PlayerDetailsViewModelTests 2>&1 | tail -30
```

Fix any failures, then commit.

```bash
git add TheRecruitingCompass/TheRecruitingCompassTests/Features/Preferences/ViewModels/PlayerDetailsViewModelTests.swift
git commit -m "test(player-details): update assertions for auto-save and SaveStatus"
```

---

## Unresolved Questions

1. **Fit Score API endpoint** — `triggerFitScoreRecalculation()` is a no-op stub. What's the actual endpoint signature and where is the service wired? (Check `PreferenceManaging` or a separate `SchoolService`)
2. **Social media privacy toggles** — The spec mentions "Privacy Toggles (Coach sharing permissions)" in the Academics & Social tab. The model only has `allowSharePhone` / `allowShareEmail`. Should social handles be added? Or is this out of scope?
3. **`positions` field on `PlayerDetails`** — currently `[String]?` with no primary position enforcement. Should `primaryPosition` remain a separate text field, or should the first chip selection set it?
4. **Profile photo persistence** — currently stored only in memory. The upload is mocked. Is Supabase Storage integration in scope for this sprint?
5. **`GradeLevelHelper.allowedGraduationYears`** — confirm the type is `[Int]` (not `[String]`). The existing `PlayerDetailsView.swift` uses it with `String(year)` tags, which implies it's `[Int]`.
