import XCTest
@testable import TheRecruitingCompass

final class PersonalFitCalculatorTests: XCTestCase {

    // Helpers ---------------------------------------------------------------
    // School / PlayerDetails have no test-friendly `fixture` factories in production —
    // per the task brief, minimal fixtures are added here (test-only), not to the types.

    private func school(state: String? = "OH",
                        studentSize: Int? = nil,
                        tuitionOOS: Double? = nil,
                        tuitionIS: Double? = nil) -> School {
        let info = AcademicInfo(state: state,
                                studentSize: studentSize,
                                tuitionInState: tuitionIS,
                                tuitionOutOfState: tuitionOOS)
        return School(
            id: "school-1",
            userId: "user-1",
            name: "Test University",
            location: nil,
            city: nil,
            state: state,
            division: nil,
            conference: nil,
            ranking: nil,
            isFavorite: false,
            website: nil,
            faviconUrl: nil,
            twitterHandle: nil,
            instagramHandle: nil,
            ncaaId: nil,
            status: "interested",
            statusChangedAt: nil,
            notes: nil,
            pros: [],
            cons: [],
            offerDetails: nil,
            academicInfo: info,
            amenities: nil,
            coachingPhilosophy: nil,
            coachingStyle: nil,
            recruitingApproach: nil,
            communicationStyle: nil,
            successMetrics: nil,
            familyUnitId: "family-1",
            createdBy: nil,
            updatedBy: nil,
            createdAt: "2025-01-01T00:00:00Z",
            updatedAt: "2025-01-01T00:00:00Z"
        )
    }

    private func athlete(homeState: String? = nil,
                         size: String? = nil,
                         cost: String? = nil) -> PlayerDetails {
        var details = PlayerDetails()
        details.schoolState = homeState
        details.campusSizePreference = size
        details.costSensitivity = cost
        return details
    }

    // Location --------------------------------------------------------------
    func testLocation_sameState_isStrong() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(homeState: "OH"),
                                                school: school(state: "OH"))
        XCTAssertEqual(a.location.strength, .strong)
        XCTAssertEqual(a.location.value, "In-state")
    }

    func testLocation_differentState_isStretch() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(homeState: "OH"),
                                                school: school(state: "MI"))
        XCTAssertEqual(a.location.strength, .stretch)
        XCTAssertEqual(a.location.value, "Out-of-state (MI)")
    }

    func testLocation_missingAthleteState_isUnknown() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(homeState: nil),
                                                school: school(state: "OH"))
        XCTAssertEqual(a.location.strength, .unknown)
    }

    // Campus size (buckets: <5000 small, 5000...25000 medium, >25000 large) --
    func testCampusSize_smallMatches() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(size: "small"),
                                                school: school(studentSize: 4999))
        XCTAssertEqual(a.campusSize.strength, .strong)
    }

    func testCampusSize_mediumBoundary5000IsMedium() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(size: "medium"),
                                                school: school(studentSize: 5000))
        XCTAssertEqual(a.campusSize.strength, .strong)
    }

    func testCampusSize_mediumBoundary25000IsMedium() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(size: "large"),
                                                school: school(studentSize: 25000))
        XCTAssertEqual(a.campusSize.strength, .stretch) // 25000 is medium, not large
    }

    func testCampusSize_largeAbove25000() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(size: "large"),
                                                school: school(studentSize: 25001))
        XCTAssertEqual(a.campusSize.strength, .strong)
    }

    func testCampusSize_noData_isUnknown() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(size: "small"),
                                                school: school(studentSize: nil))
        XCTAssertEqual(a.campusSize.strength, .unknown)
    }

    func testCampusSize_noPreference_isUnknown() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(size: nil),
                                                school: school(studentSize: 3000))
        XCTAssertEqual(a.campusSize.strength, .unknown)
    }

    // Cost (uses tuitionOutOfState ?? tuitionInState) -----------------------
    func testCost_highSensitivity_tiers() {
        XCTAssertEqual(PersonalFitCalculator.calculate(athlete: athlete(cost: "high"),
            school: school(tuitionOOS: 20000)).cost.strength, .strong)
        XCTAssertEqual(PersonalFitCalculator.calculate(athlete: athlete(cost: "high"),
            school: school(tuitionOOS: 35000)).cost.strength, .good)
        XCTAssertEqual(PersonalFitCalculator.calculate(athlete: athlete(cost: "high"),
            school: school(tuitionOOS: 35001)).cost.strength, .stretch)
    }

    func testCost_mediumSensitivity_tiers() {
        XCTAssertEqual(PersonalFitCalculator.calculate(athlete: athlete(cost: "medium"),
            school: school(tuitionOOS: 35000)).cost.strength, .strong)
        XCTAssertEqual(PersonalFitCalculator.calculate(athlete: athlete(cost: "medium"),
            school: school(tuitionOOS: 55000)).cost.strength, .good)
        XCTAssertEqual(PersonalFitCalculator.calculate(athlete: athlete(cost: "medium"),
            school: school(tuitionOOS: 55001)).cost.strength, .stretch)
    }

    func testCost_lowSensitivity_alwaysStrong() {
        XCTAssertEqual(PersonalFitCalculator.calculate(athlete: athlete(cost: "low"),
            school: school(tuitionOOS: 90000)).cost.strength, .strong)
    }

    func testCost_fallsBackToInState() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(cost: "high"),
            school: school(tuitionOOS: nil, tuitionIS: 15000))
        XCTAssertEqual(a.cost.strength, .strong)
    }

    func testCost_noData_isUnknown() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(cost: "high"),
            school: school(tuitionOOS: nil, tuitionIS: nil))
        XCTAssertEqual(a.cost.strength, .unknown)
    }

    // availableSignals + overall rollup -------------------------------------
    func testAvailableSignals_countsNonUnknown() {
        let a = PersonalFitCalculator.calculate(
            athlete: athlete(homeState: "OH", size: "small", cost: "low"),
            school: school(state: "OH", studentSize: 3000, tuitionOOS: 10000))
        XCTAssertEqual(a.availableSignals, 3)
    }

    func testOverall_allStrong_isStrong() {
        let a = PersonalFitCalculator.calculate(
            athlete: athlete(homeState: "OH", size: "small", cost: "low"),
            school: school(state: "OH", studentSize: 3000, tuitionOOS: 10000))
        XCTAssertEqual(PersonalFitCalculator.overall(a)?.strength, .strong)
    }

    func testOverall_mixedStrongStretch_meanBucketing() {
        // location strong(2) + campus stretch(0) = mean 1.0 -> good (>=0.75)
        let a = PersonalFitCalculator.calculate(
            athlete: athlete(homeState: "OH", size: "large"),
            school: school(state: "OH", studentSize: 3000))
        XCTAssertEqual(a.availableSignals, 2)
        XCTAssertEqual(PersonalFitCalculator.overall(a)?.strength, .good)
    }

    func testOverall_bothStretch_isStretch() {
        let a = PersonalFitCalculator.calculate(
            athlete: athlete(homeState: "OH", size: "large"),
            school: school(state: "MI", studentSize: 3000))
        XCTAssertEqual(PersonalFitCalculator.overall(a)?.strength, .stretch)
    }

    func testOverall_noSignals_isNil() {
        let a = PersonalFitCalculator.calculate(athlete: athlete(), school: school())
        XCTAssertEqual(a.availableSignals, 0)
        XCTAssertNil(PersonalFitCalculator.overall(a))
    }
}
